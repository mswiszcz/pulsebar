import Foundation

enum Format {
  private static let bytes = ByteCountFormatStyle(style: .memory, spellsOutZero: false)
  private static let storage = ByteCountFormatStyle(style: .file, spellsOutZero: false)

  static func memory(_ value: UInt64) -> String {
    bytes.format(Int64(value))
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
}
