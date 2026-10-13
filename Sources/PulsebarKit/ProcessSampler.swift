import Darwin
import Foundation

struct ProcessSampler {
  private static let largeAppMinimum: UInt64 = 100 * 1_048_576
  private static let detailLimit = 5

  private let secondsPerTick: Double
  private let coreCount = Double(ProcessInfo.processInfo.activeProcessorCount)
  private let home = FileManager.default.homeDirectoryForCurrentUser.path
  private var previousTicks: [ProcessID: UInt64] = [:]
  private var previousTime: Double?
  private var identities = ProcessCache<AppIdentity?>()
  private var roles = ProcessCache<String>()
  private var startDates = ProcessCache<Date?>()

  init() {
    var timebase = mach_timebase_info()
    mach_timebase_info(&timebase)
    secondsPerTick = Double(timebase.numer) / Double(timebase.denom) / 1_000_000_000
  }

  mutating func sample(at time: Double, includeDetails: Bool) -> ProcessSnapshot {
    let interval = time - (previousTime ?? time)
    var processes: [ProcessUsage] = []
    var currentTicks: [ProcessID: UInt64] = [:]

    for pid in Self.allPIDs() {
      guard let usage = Self.resourceUsage(pid) else { continue }
      let id = ProcessID(pid: pid, startTime: usage.ri_proc_start_abstime)
      let ticks = usage.ri_user_time + usage.ri_system_time
      currentTicks[id] = ticks
      guard let app = identities.value(for: id, { Self.identity(pid) }) else { continue }
      let ticksPerSecond = CounterRate.perSecond(
        previous: previousTicks[id], current: ticks, interval: interval)
      processes.append(
        ProcessUsage(
          id: id, app: app, memory: usage.ri_phys_footprint,
          cpuShare: ticksPerSecond.map { $0 * secondsPerTick / coreCount }))
    }

    previousTicks = currentTicks
    previousTime = time
    identities.retain(Set(currentTicks.keys))
    let all = TopApps.aggregate(processes)
    let culprits = TopApps.culprits(all, byMemory: 6, byCPU: 3)
    return ProcessSnapshot(
      apps: culprits,
      largeApps: MemoryGrowth.snapshot(all, minimum: Self.largeAppMinimum),
      details: includeDetails ? details(for: culprits, in: processes) : [:]
    )
  }

  private mutating func details(
    for apps: [AppUsage], in processes: [ProcessUsage]
  ) -> [AppIdentity: [ProcessDetail]] {
    var details: [AppIdentity: [ProcessDetail]] = [:]
    var seen: Set<ProcessID> = []
    for usage in apps {
      details[usage.app] = TopApps.topProcesses(processes, of: usage.app, limit: Self.detailLimit)
        .map { process in
          seen.insert(process.id)
          return ProcessDetail(
            id: process.id,
            label: label(for: process),
            memory: process.memory,
            cpuShare: process.cpuShare,
            started: startDates.value(for: process.id) { Self.startDate(process.id.pid) }
          )
        }
    }
    roles.retain(seen)
    startDates.retain(seen)
    return details
  }

  private mutating func label(for process: ProcessUsage) -> String {
    if process.app.bundlePath == nil {
      return Self.workingDirectory(process.id.pid).map { PathAbbreviation.short($0, home: home) }
        ?? process.app.name
    }
    return roles.value(for: process.id) { Self.role(process.id.pid) ?? process.app.name }
  }

  private static func role(_ pid: pid_t) -> String? {
    withProcArgs(pid) { bytes in
      ProcessArguments.executablePath(fromProcArgs: bytes).map { path in
        ProcessRole.name(
          arguments: ProcessArguments.arguments(fromProcArgs: bytes), executablePath: path)
      }
    }
  }

  private static func startDate(_ pid: pid_t) -> Date? {
    var info = proc_bsdinfo()
    let size = Int32(MemoryLayout<proc_bsdinfo>.size)
    guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
    return Date(
      timeIntervalSince1970: Double(info.pbi_start_tvsec) + Double(info.pbi_start_tvusec) / 1e6)
  }

  private static func workingDirectory(_ pid: pid_t) -> String? {
    var info = proc_vnodepathinfo()
    let size = Int32(MemoryLayout<proc_vnodepathinfo>.size)
    guard proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, size) == size else { return nil }
    let path = withUnsafeBytes(of: info.pvi_cdir.vip_path) { bytes in
      String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
    }
    return path.isEmpty ? nil : path
  }

  private static func allPIDs() -> [pid_t] {
    let capacity = Int(proc_listallpids(nil, 0)) + 64
    var pids = [pid_t](repeating: 0, count: capacity)
    let count = proc_listallpids(&pids, Int32(capacity * MemoryLayout<pid_t>.stride))
    return count > 0 ? Array(pids.prefix(Int(count))) : []
  }

  private static func resourceUsage(_ pid: pid_t) -> rusage_info_v4? {
    var usage = rusage_info_v4()
    let result = withUnsafeMutablePointer(to: &usage) {
      $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
        proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
      }
    }
    return result == 0 ? usage : nil
  }

  private static func identity(_ pid: pid_t) -> AppIdentity? {
    (launchPath(pid) ?? resolvedPath(pid)).flatMap(AppGrouping.identity(forExecutablePath:))
  }

  private static func launchPath(_ pid: pid_t) -> String? {
    withProcArgs(pid) { ProcessArguments.executablePath(fromProcArgs: $0) }
  }

  private static func withProcArgs<Result>(
    _ pid: pid_t, _ body: (ArraySlice<UInt8>) -> Result?
  ) -> Result? {
    var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
    var size = Int(ARG_MAX)
    let bytes = [UInt8](unsafeUninitializedCapacity: size) { buffer, count in
      count = sysctl(&mib, UInt32(mib.count), buffer.baseAddress, &size, nil, 0) == 0 ? size : 0
    }
    return bytes.isEmpty ? nil : body(bytes[...])
  }

  private static func resolvedPath(_ pid: pid_t) -> String? {
    var buffer = [UInt8](repeating: 0, count: 4 * Int(MAXPATHLEN))
    let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
    return length > 0 ? String(decoding: buffer.prefix(Int(length)), as: UTF8.self) : nil
  }
}
