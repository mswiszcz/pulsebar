public enum FailureReason: Error, Equatable, Sendable {
  case timeout
  case cannotConnect
  case httpStatus(Int)
  case bodyTooLarge
  case notNodeExporter
  case localNetworkDenied
  case other(String)
}

public struct ServerReading: Equatable, Sendable {
  public let metrics: NodeMetrics
  public let rates: NodeRates
  public let time: Double
}

public enum ServerState: Equatable, Sendable {
  case unknown
  case up(ServerReading)
  case unreachable(lastSeen: Double?, reason: FailureReason)
}

public struct ServerHistorySample: Equatable, Sendable {
  public let cpu: Double?
  public let memory: Double?
  public let gpuBusy: Double?
  public let vram: Double?

  public static let gap = ServerHistorySample(cpu: nil, memory: nil, gpuBusy: nil, vram: nil)
}

public struct ServerTracker: Sendable {
  public static let historyCapacity = 30
  public static let sampleInterval = PollBackoff.interval

  public private(set) var state: ServerState = .unknown
  public private(set) var backoff = PollBackoff()
  public private(set) var history = RingBuffer<ServerHistorySample>(
    capacity: ServerTracker.historyCapacity)

  public init() {}

  public mutating func record(_ result: Result<NodeMetrics, FailureReason>, at time: Double) {
    switch result {
    case .success(let metrics) where metrics.isNodeExporter:
      accept(metrics, at: time)
    case .success:
      reject(.notNodeExporter, at: time)
    case .failure(let reason):
      reject(reason, at: time)
    }
  }

  private var lastReading: ServerReading? {
    if case .up(let reading) = state { reading } else { nil }
  }

  private var lastSeen: Double? {
    switch state {
    case .unknown: nil
    case .up(let reading): reading.time
    case .unreachable(let lastSeen, _): lastSeen
    }
  }

  private mutating func accept(_ metrics: NodeMetrics, at time: Double) {
    let previous = lastReading
    let rates = NodeRates(
      current: metrics, previous: previous?.metrics, interval: time - (previous?.time ?? time))
    state = .up(ServerReading(metrics: metrics, rates: rates, time: time))
    history.append(
      ServerHistorySample(
        cpu: rates.cpuFraction,
        memory: metrics.memoryFraction,
        gpuBusy: metrics.fullestGPU?.busyFraction,
        vram: metrics.fullestGPU?.vramFraction))
    backoff.record(success: true, at: time)
  }

  private mutating func reject(_ reason: FailureReason, at time: Double) {
    state = .unreachable(lastSeen: lastSeen, reason: reason)
    history.append(.gap)
    backoff.record(success: false, at: time)
  }
}
