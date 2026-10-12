public struct CPUTicks: Equatable, Sendable {
  public let user: UInt64
  public let system: UInt64
  public let idle: UInt64
  public let nice: UInt64

  public init(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64) {
    self.user = user
    self.system = system
    self.idle = idle
    self.nice = nice
  }

  public func busyFraction(since previous: CPUTicks) -> Double? {
    guard user >= previous.user, system >= previous.system, idle >= previous.idle,
      nice >= previous.nice
    else { return nil }
    let busy = (user - previous.user) + (system - previous.system)
    let total = busy + (idle - previous.idle) + (nice - previous.nice)
    return total > 0 ? Double(busy) / Double(total) : nil
  }
}
