import Darwin
import Foundation

struct MemorySampler {
  private let host = mach_host_self()

  func sample() -> MemoryStats? {
    guard let vm = vmStatistics(), let pageSize = kernelPageSize(),
      let level = sysctlValue("kern.memorystatus_level", initial: Int32(0)),
      let pressure = sysctlValue("kern.memorystatus_vm_pressure_level", initial: Int32(0)),
      let swap = sysctlValue("vm.swapusage", initial: xsw_usage())
    else { return nil }
    return MemoryStats(
      pressure: PressureLevel(kernelLevel: pressure),
      availablePercent: Int(level),
      breakdown: MemoryBreakdown(
        pageSize: pageSize,
        internalPages: UInt64(vm.internal_page_count),
        purgeablePages: UInt64(vm.purgeable_count),
        externalPages: UInt64(vm.external_page_count),
        wiredPages: UInt64(vm.wire_count),
        compressorPages: UInt64(vm.compressor_page_count)
      ),
      total: ProcessInfo.processInfo.physicalMemory,
      swapUsed: swap.xsu_used,
      swapTotal: swap.xsu_total
    )
  }

  private func kernelPageSize() -> UInt64? {
    var pageSize: vm_size_t = 0
    return host_page_size(host, &pageSize) == KERN_SUCCESS ? UInt64(pageSize) : nil
  }

  private func vmStatistics() -> vm_statistics64? {
    var stats = vm_statistics64()
    var count = mach_msg_type_number_t(
      MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
    let result = withUnsafeMutablePointer(to: &stats) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        host_statistics64(host, HOST_VM_INFO64, $0, &count)
      }
    }
    return result == KERN_SUCCESS ? stats : nil
  }

  private func sysctlValue<Value: BitwiseCopyable>(_ name: String, initial: Value) -> Value? {
    var value = initial
    var size = MemoryLayout<Value>.size
    return sysctlbyname(name, &value, &size, nil, 0) == 0 ? value : nil
  }
}

extension PressureLevel {
  init(kernelLevel: Int32) {
    switch kernelLevel {
    case 4: self = .critical
    case 2: self = .warning
    default: self = .normal
    }
  }
}
