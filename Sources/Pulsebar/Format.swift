import Foundation

enum Format {
  private static let bytes = ByteCountFormatStyle(style: .memory, spellsOutZero: false)
  private static let storage = ByteCountFormatStyle(style: .file, spellsOutZero: false)
  private static let gibibyte = 1_073_741_824.0
  private static let mebibyte = 1_048_576.0

  static func memory(_ value: UInt64) -> String {
    bytes.format(Int64(value))
  }

  static func gigabytes(_ value: UInt64) -> String {
    (Double(value) / gibibyte).formatted(.number.precision(.fractionLength(1)))
  }

  static func appMemory(_ value: UInt64) -> String {
    let amount = Double(value)
    guard amount >= gibibyte else {
      return "\((amount / mebibyte).formatted(.number.precision(.fractionLength(0)))) MB"
    }
    return "\(gigabytes(value)) GB"
  }

  static func growth(_ bytes: UInt64, minutes: Int) -> String {
    "+\(appMemory(bytes)) / \(minutes) min"
  }

  static func uptime(since start: Date) -> String {
    duration(Date.now.timeIntervalSince(start))
  }

  static func duration(_ seconds: Double, width: Duration.UnitsFormatStyle.UnitWidth = .narrow)
    -> String
  {
    Duration.seconds(max(seconds, 0)).formatted(
      .units(allowed: [.days, .hours, .minutes, .seconds], width: width, maximumUnitCount: 1))
  }

  static func disk(_ value: Int64) -> String {
    storage.format(value)
  }

  static func rate(_ bytesPerSecond: Double?) -> String {
    bytesPerSecond.map { storage.format(Int64($0)) + "/s" } ?? "—"
  }

  static func percent(_ fraction: Double?) -> String {
    fraction.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "—"
  }

  static func cpuShare(_ share: Double?) -> String {
    share.map { $0.formatted(.percent.precision(.fractionLength($0 < 0.1 ? 1 : 0))) } ?? "—"
  }

  static func wholePercent(_ fraction: Double?) -> String {
    fraction.map { "\(Int((min(max($0, 0), 1) * 100).rounded()))%" } ?? "–%"
  }
}
