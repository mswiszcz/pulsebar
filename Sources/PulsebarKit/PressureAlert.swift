public struct PressureAlert: Equatable, Sendable {
  public let title: String
  public let body: String

  public init(
    level: PressureLevel, growth: [AppIdentity: UInt64], growthMinutes: Int, apps: [AppUsage],
    formatBytes: (UInt64) -> String
  ) {
    title = level == .critical ? "Memory critical" : "Memory under pressure"
    if let grower = growth.max(by: { $0.value < $1.value }) {
      body = "\(grower.key.name) grew \(formatBytes(grower.value)) in \(growthMinutes) min"
    } else if let biggest = apps.max(by: { $0.memory < $1.memory }) {
      body = "\(biggest.app.name) uses \(formatBytes(biggest.memory))"
    } else {
      body = ""
    }
  }
}
