import Darwin

struct CPUSampler {
  private let host = mach_host_self()
  private var previous: CPUTicks?

  mutating func sample() -> Double? {
    guard let current = ticks() else { return nil }
    defer { previous = current }
    return previous.flatMap { current.busyFraction(since: $0) }
  }

  private func ticks() -> CPUTicks? {
    var processorCount: natural_t = 0
    var info: processor_info_array_t?
    var infoCount: mach_msg_type_number_t = 0
    guard
      host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &processorCount, &info, &infoCount)
        == KERN_SUCCESS,
      let info
    else { return nil }
    defer {
      vm_deallocate(
        mach_task_self_, vm_address_t(bitPattern: info),
        vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride))
    }
    let states = Int(CPU_STATE_MAX)
    func total(_ state: Int32) -> UInt64 {
      (0..<Int(processorCount)).reduce(0) {
        $0 + UInt64(UInt32(bitPattern: info[$1 * states + Int(state)]))
      }
    }
    return CPUTicks(
      user: total(CPU_STATE_USER), system: total(CPU_STATE_SYSTEM),
      idle: total(CPU_STATE_IDLE), nice: total(CPU_STATE_NICE))
  }
}
