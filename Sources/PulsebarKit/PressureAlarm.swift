public struct PressureAlarm: Sendable {
  private let sustain: Double
  private let rearm: Double
  private var elevatedSince: Double?
  private var criticalSince: Double?
  private var normalSince: Double?
  private var notified: PressureLevel?

  public init(sustain: Double = 10, rearm: Double = 60) {
    self.sustain = sustain
    self.rearm = rearm
  }

  public mutating func update(
    level: PressureLevel, at time: Double, minimum: PressureLevel
  ) -> PressureLevel? {
    guard level != .normal else {
      elevatedSince = nil
      criticalSince = nil
      let since = normalSince ?? time
      normalSince = since
      if time - since >= rearm { notified = nil }
      return nil
    }
    normalSince = nil
    let elevated = elevatedSince ?? time
    elevatedSince = elevated
    criticalSince = level == .critical ? (criticalSince ?? time) : nil

    let sustained: PressureLevel? =
      criticalSince.map { time - $0 >= sustain } == true
      ? .critical : time - elevated >= sustain ? .warning : nil
    guard let sustained, sustained >= minimum, sustained > (notified ?? .normal) else {
      return nil
    }
    notified = sustained
    return sustained
  }
}
