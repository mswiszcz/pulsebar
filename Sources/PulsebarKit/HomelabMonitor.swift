import Foundation

public struct ServerSnapshot: Sendable, Identifiable {
  public let config: ServerConfig
  public let state: ServerState
  public let history: [ServerHistorySample]

  public var id: UUID { config.id }
}

public actor HomelabMonitor {
  private static let maximumBodySize = 2_000_000
  private static let localNetworkMarker = "Local network prohibited"

  private nonisolated let session: URLSession
  private var servers: [ServerConfig] = []
  private var trackers: [UUID: ServerTracker] = [:]

  public init() {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 3
    configuration.timeoutIntervalForResource = 3
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    configuration.urlCache = nil
    session = URLSession(configuration: configuration)
  }

  public func configure(_ servers: [ServerConfig]) {
    self.servers = servers
    let ids = Set(servers.map(\.id))
    trackers = trackers.filter { ids.contains($0.key) }
    for server in servers where trackers[server.id] == nil {
      trackers[server.id] = ServerTracker()
    }
  }

  public func poll(at time: Double, staleOnly: Bool) async -> [ServerSnapshot] {
    let selected = servers.filter { server in
      let backoff = (trackers[server.id] ?? ServerTracker()).backoff
      return staleOnly ? backoff.isStale(at: time) : backoff.isDue(at: time)
    }
    await withTaskGroup(of: (UUID, Result<NodeMetrics, FailureReason>).self) { group in
      for server in selected {
        group.addTask { (server.id, await self.fetch(server.url)) }
      }
      for await (id, result) in group {
        guard !Task.isCancelled else { continue }
        trackers[id]?.record(result, at: time)
      }
    }
    return servers.map { server in
      let tracker = trackers[server.id] ?? ServerTracker()
      return ServerSnapshot(
        config: server, state: tracker.state, history: tracker.history.elements)
    }
  }

  public func secondsUntilNextPoll(at time: Double) -> Double {
    let remaining = servers.map { server in
      let backoff = (trackers[server.id] ?? ServerTracker()).backoff
      return (backoff.lastPoll ?? time) + backoff.currentInterval - time
    }
    return max(remaining.min() ?? PollBackoff.interval, 1)
  }

  public nonisolated func fetch(_ url: URL) async -> Result<NodeMetrics, FailureReason> {
    let result = await fetch(url, includeGPU: true)
    guard case .failure(.httpStatus(400)) = result else { return result }
    return await fetch(url, includeGPU: false)
  }

  private nonisolated func fetch(
    _ url: URL, includeGPU: Bool
  ) async -> Result<NodeMetrics, FailureReason> {
    do {
      let (bytes, response) = try await session.bytes(
        for: URLRequest(url: ServerURL.metricsRequest(url, includeGPU: includeGPU)))
      guard let http = response as? HTTPURLResponse else {
        return .failure(.other("Not an HTTP response"))
      }
      guard (200..<300).contains(http.statusCode) else {
        return .failure(.httpStatus(http.statusCode))
      }
      guard http.expectedContentLength <= Int64(Self.maximumBodySize) else {
        return .failure(.bodyTooLarge)
      }
      var body: [UInt8] = []
      for try await byte in bytes {
        body.append(byte)
        guard body.count <= Self.maximumBodySize else { return .failure(.bodyTooLarge) }
      }
      let metrics = NodeMetrics(samples: PrometheusText.parse(body))
      guard metrics.isNodeExporter else { return .failure(.notNodeExporter) }
      return .success(metrics)
    } catch {
      return .failure(Self.failureReason(for: error))
    }
  }

  private static func failureReason(for error: Error) -> FailureReason {
    let nsError = error as NSError
    if String(describing: nsError.userInfo["_NSURLErrorNWPathKey"]).contains(localNetworkMarker) {
      return .localNetworkDenied
    }
    guard let urlError = error as? URLError else { return .other(error.localizedDescription) }
    switch urlError.code {
    case .timedOut:
      return .timeout
    case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed, .networkConnectionLost,
      .notConnectedToInternet:
      return .cannotConnect
    default:
      return .other(error.localizedDescription)
    }
  }
}
