public enum CounterRate {
  public static func perSecond(previous: UInt64?, current: UInt64, interval: Double) -> Double? {
    guard let previous, current >= previous, interval > 0 else { return nil }
    return Double(current - previous) / interval
  }
}

public struct RateMeter: Sendable {
  private var last: (value: UInt64, time: Double)?

  public init() {}

  public mutating func update(value: UInt64, at time: Double) -> Double? {
    defer { last = (value, time) }
    return CounterRate.perSecond(
      previous: last?.value, current: value, interval: time - (last?.time ?? time))
  }
}
