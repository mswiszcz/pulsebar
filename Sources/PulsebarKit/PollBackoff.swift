public struct PollBackoff: Equatable, Sendable {
  public static let interval = 10.0
  public static let backoffInterval = 60.0
  public static let failureThreshold = 3

  public private(set) var consecutiveFailures = 0
  public private(set) var lastPoll: Double?

  public init() {}

  public mutating func record(success: Bool, at time: Double) {
    lastPoll = time
    consecutiveFailures = success ? 0 : consecutiveFailures + 1
  }

  public var currentInterval: Double {
    consecutiveFailures >= Self.failureThreshold ? Self.backoffInterval : Self.interval
  }

  public func isDue(at time: Double) -> Bool {
    elapsed(at: time) >= currentInterval
  }

  public func isStale(at time: Double) -> Bool {
    elapsed(at: time) >= Self.interval
  }

  private func elapsed(at time: Double) -> Double {
    lastPoll.map { time - $0 } ?? .infinity
  }
}
