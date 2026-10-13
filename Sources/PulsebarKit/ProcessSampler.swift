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
  private var argumentsBuffer = [UInt8](repeating: 0, count: Int(ARG_MAX))
  private var roles: [ProcessID: String] = [:]
  private var startDates: [ProcessID: Date] = [:]

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
      guard let usage = Self.resourceUsage(pid),
        let path = launchPath(pid) ?? Self.resolvedPath(pid),
        let app = AppGrouping.identity(forExecutablePath: path)
      else { continue }
      let id = ProcessID(pid: pid, startTime: usage.ri_proc_start_abstime)
      let ticks = usage.ri_user_time + usage.ri_system_time
      currentTicks[id] = ticks
      let ticksPerSecond = CounterRate.perSecond(
        previous: previousTicks[id], current: ticks, interval: interval)
      processes.append(
        ProcessUsage(
          id: id, app: app, memory: usage.ri_phys_footprint,
          cpuShare: ticksPerSecond.map { $0 * secondsPerTick / coreCount }))
    }

    previousTicks = currentTicks
    previousTime = time
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
            started: startDate(process.id)
          )
        }
    }
    roles = roles.filter { seen.contains($0.key) }
    startDates = startDates.filter { seen.contains($0.key) }
    return details
  }

  private mutating func label(for process: ProcessUsage) -> String {
    if process.app.bundlePath == nil {
      return Self.workingDirectory(process.id.pid).map { PathAbbreviation.short($0, home: home) }
        ?? process.app.name
    }
    if let role = roles[process.id] { return role }
    let role = role(process.id.pid) ?? process.app.name
    roles[process.id] = role
    return role
  }

  private mutating func role(_ pid: pid_t) -> String? {
    withProcArgs(pid) { bytes in
      ProcessArguments.executablePath(fromProcArgs: bytes).map { path in
        ProcessRole.name(
          arguments: ProcessArguments.arguments(fromProcArgs: bytes), executablePath: path)
      }
    }
  }

  private mutating func startDate(_ id: ProcessID) -> Date? {
    if let date = startDates[id] { return date }
    var info = proc_bsdinfo()
    let size = Int32(MemoryLayout<proc_bsdinfo>.size)
    guard proc_pidinfo(id.pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
    let date = Date(
      timeIntervalSince1970: Double(info.pbi_start_tvsec) + Double(info.pbi_start_tvusec) / 1e6)
    startDates[id] = date
    return date
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

  private mutating func launchPath(_ pid: pid_t) -> String? {
    withProcArgs(pid) { ProcessArguments.executablePath(fromProcArgs: $0) }
  }

  private mutating func withProcArgs<Result>(
    _ pid: pid_t, _ body: (ArraySlice<UInt8>) -> Result?
  ) -> Result? {
    var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
    var size = argumentsBuffer.count
    guard sysctl(&mib, UInt32(mib.count), &argumentsBuffer, &size, nil, 0) == 0 else {
      return nil
    }
    return body(argumentsBuffer[..<size])
  }

  private static func resolvedPath(_ pid: pid_t) -> String? {
    var buffer = [UInt8](repeating: 0, count: 4 * Int(MAXPATHLEN))
    let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
    return length > 0 ? String(decoding: buffer.prefix(Int(length)), as: UTF8.self) : nil
  }
}
