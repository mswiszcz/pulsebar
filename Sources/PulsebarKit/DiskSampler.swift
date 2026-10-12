import Foundation
import IOKit

struct DiskSampler {
  private var readMeter = RateMeter()
  private var writeMeter = RateMeter()
  private var space: (value: DiskSpace?, time: Double)?
  private let spaceRefreshInterval: Double = 30

  mutating func sample(at time: Double) -> DiskStats {
    if space.map({ time - $0.time >= spaceRefreshInterval }) ?? true {
      space = (Self.rootVolumeSpace(), time)
    }
    let counters = Self.ioCounters()
    return DiskStats(
      space: space?.value,
      readRate: counters.flatMap { readMeter.update(value: $0.read, at: time) },
      writeRate: counters.flatMap { writeMeter.update(value: $0.written, at: time) }
    )
  }

  private static func rootVolumeSpace() -> DiskSpace? {
    let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: [
      .volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey,
    ])
    guard let available = values?.volumeAvailableCapacityForImportantUsage,
      let total = values?.volumeTotalCapacity
    else { return nil }
    return DiskSpace(available: available, total: Int64(total))
  }

  private static func ioCounters() -> (read: UInt64, written: UInt64)? {
    var iterator: io_iterator_t = 0
    guard
      IOServiceGetMatchingServices(
        kIOMainPortDefault, IOServiceMatching("IOBlockStorageDriver"), &iterator) == KERN_SUCCESS
    else { return nil }
    defer { IOObjectRelease(iterator) }

    var read: UInt64 = 0
    var written: UInt64 = 0
    while case let service = IOIteratorNext(iterator), service != 0 {
      defer { IOObjectRelease(service) }
      let statistics =
        IORegistryEntryCreateCFProperty(
          service, "Statistics" as CFString, kCFAllocatorDefault, 0)?
        .takeRetainedValue() as? [String: Any]
      read += (statistics?["Bytes (Read)"] as? NSNumber)?.uint64Value ?? 0
      written += (statistics?["Bytes (Write)"] as? NSNumber)?.uint64Value ?? 0
    }
    return (read, written)
  }
}
