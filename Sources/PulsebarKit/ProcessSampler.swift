import Darwin
import Foundation

struct ProcessSampler {
  private struct ProcessKey: Hashable {
    let pid: pid_t
    let startTime: UInt64
  }

  private let secondsPerTick: Double
  private let coreCount = Double(ProcessInfo.processInfo.activeProcessorCount)
  private var previousTicks: [ProcessKey: UInt64] = [:]
  private var previousTime: Double?
  private var argumentsBuffer = [UInt8](repeating: 0, count: Int(ARG_MAX))

  init() {
    var timebase = mach_timebase_info()
    mach_timebase_info(&timebase)
    secondsPerTick = Double(timebase.numer) / Double(timebase.denom) / 1_000_000_000
  }

  mutating func sample(at time: Double) -> [AppUsage] {
    let interval = time - (previousTime ?? time)
    var processes: [ProcessUsage] = []
    var currentTicks: [ProcessKey: UInt64] = [:]

    for pid in Self.allPIDs() {
      guard let usage = Self.resourceUsage(pid),
        let path = launchPath(pid) ?? Self.resolvedPath(pid),
        let app = AppGrouping.identity(forExecutablePath: path)
      else { continue }
      let key = ProcessKey(pid: pid, startTime: usage.ri_proc_start_abstime)
      let ticks = usage.ri_user_time + usage.ri_system_time
      currentTicks[key] = ticks
      let ticksPerSecond = CounterRate.perSecond(
        previous: previousTicks[key], current: ticks, interval: interval)
      processes.append(
        ProcessUsage(
          app: app, memory: usage.ri_phys_footprint,
          cpuShare: ticksPerSecond.map { $0 * secondsPerTick / coreCount }))
    }

    previousTicks = currentTicks
    previousTime = time
    return TopApps.culprits(TopApps.aggregate(processes), byMemory: 6, byCPU: 3)
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
    var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
    var size = argumentsBuffer.count
    guard sysctl(&mib, UInt32(mib.count), &argumentsBuffer, &size, nil, 0) == 0 else {
      return nil
    }
    return ProcessArguments.executablePath(fromProcArgs: argumentsBuffer.prefix(size))
  }

  private static func resolvedPath(_ pid: pid_t) -> String? {
    var buffer = [UInt8](repeating: 0, count: 4 * Int(MAXPATHLEN))
    let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
    return length > 0 ? String(decoding: buffer.prefix(Int(length)), as: UTF8.self) : nil
  }
}
