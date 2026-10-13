import PulsebarKit
import Testing

struct ServerTrackerTests {
  private func node(
    busy: Double = 0, idle: Double = 100, memoryUsed: Double = 0, received: Double = 0,
    extra: [MetricSample] = []
  ) -> NodeMetrics {
    NodeMetrics(
      samples: [
        MetricSample(
          name: "node_cpu_seconds_total", labels: ["cpu": "0", "mode": "user"], value: busy),
        MetricSample(
          name: "node_cpu_seconds_total", labels: ["cpu": "0", "mode": "idle"], value: idle),
        MetricSample(name: "node_memory_MemTotal_bytes", value: 100),
        MetricSample(name: "node_memory_MemAvailable_bytes", value: 100 - memoryUsed),
        MetricSample(
          name: "node_network_receive_bytes_total", labels: ["device": "eth0"], value: received),
      ] + extra)
  }

  private func reading(_ state: ServerState) -> ServerReading? {
    if case .up(let reading) = state { reading } else { nil }
  }

  private func recording(_ results: [(Result<NodeMetrics, FailureReason>, Double)]) -> ServerTracker
  {
    var tracker = ServerTracker()
    for (result, time) in results { tracker.record(result, at: time) }
    return tracker
  }

  @Test func startsUnknownWithEmptyHistory() {
    let tracker = ServerTracker()
    #expect(tracker.state == .unknown)
    #expect(tracker.history.elements.isEmpty)
  }

  @Test func successIsUpWithMemorySample() {
    let tracker = recording([(.success(node(memoryUsed: 25)), 0)])
    #expect(reading(tracker.state)?.time == 0)
    #expect(tracker.history.elements.last?.memory == 0.25)
  }

  @Test func secondSuccessDerivesCPUAndNetworkRates() {
    let tracker = recording([
      (.success(node(busy: 10, idle: 90, received: 1000)), 0),
      (.success(node(busy: 30, idle: 170, received: 3000)), 10),
    ])
    #expect(reading(tracker.state)?.rates.cpuFraction == 0.2)
    #expect(reading(tracker.state)?.rates.downRate == 200)
  }

  @Test func failureBeforeAnySuccessHasNoLastSeen() {
    let tracker = recording([(.failure(.timeout), 0)])
    #expect(tracker.state == .unreachable(lastSeen: nil, reason: .timeout))
  }

  @Test func failureAfterSuccessKeepsLastSeen() {
    let tracker = recording([
      (.success(node()), 5),
      (.failure(.cannotConnect), 10),
      (.failure(.timeout), 15),
    ])
    #expect(tracker.state == .unreachable(lastSeen: 5, reason: .timeout))
  }

  @Test func failureAppendsGapSample() {
    let tracker = recording([(.success(node()), 0), (.failure(.timeout), 10)])
    #expect(tracker.history.elements.count == 2)
    #expect(tracker.history.elements.last == ServerHistorySample.gap)
  }

  @Test func nonNodeExporterIsUnreachable() {
    let body = NodeMetrics(samples: [MetricSample(name: "node_load1", value: 1)])
    let tracker = recording([(.success(body), 0)])
    #expect(tracker.state == .unreachable(lastSeen: nil, reason: .notNodeExporter))
  }

  @Test func firstSuccessAfterOutageHasNoRates() {
    let tracker = recording([
      (.success(node(busy: 10, idle: 90)), 0),
      (.failure(.timeout), 10),
      (.success(node(busy: 30, idle: 170)), 20),
    ])
    #expect(reading(tracker.state)?.rates.cpuFraction == nil)
    #expect(reading(tracker.state)?.rates.downRate == nil)
  }

  @Test func counterResetHasNoCPUFraction() {
    let tracker = recording([
      (.success(node(busy: 100, idle: 100)), 0),
      (.success(node(busy: 10, idle: 10)), 10),
    ])
    #expect(reading(tracker.state)?.rates.cpuFraction == nil)
  }

  @Test func threeFailuresBackOffThenSuccessRecovers() {
    var tracker = recording([
      (.failure(.timeout), 0),
      (.failure(.timeout), 10),
      (.failure(.timeout), 20),
    ])
    #expect(tracker.backoff.currentInterval == 60)
    tracker.record(.success(node()), at: 80)
    #expect(tracker.backoff.currentInterval == 10)
  }

  @Test func historyIsCappedAtCapacity() {
    let results = (0..<35).map { (Result<NodeMetrics, FailureReason>.success(node()), Double($0)) }
    let tracker = recording(results)
    #expect(ServerTracker.historyCapacity == 30)
    #expect(tracker.history.elements.count == 30)
  }

  @Test func fullestGPUFeedsVRAMAndBusyHistory() {
    let gpus = [
      MetricSample(name: "node_drm_memory_vram_used_bytes", labels: ["card": "card0"], value: 10),
      MetricSample(name: "node_drm_memory_vram_size_bytes", labels: ["card": "card0"], value: 100),
      MetricSample(name: "node_drm_gpu_busy_percent", labels: ["card": "card0"], value: 5),
      MetricSample(name: "node_drm_memory_vram_used_bytes", labels: ["card": "card1"], value: 80),
      MetricSample(name: "node_drm_memory_vram_size_bytes", labels: ["card": "card1"], value: 100),
      MetricSample(name: "node_drm_gpu_busy_percent", labels: ["card": "card1"], value: 50),
    ]
    let tracker = recording([(Result<NodeMetrics, FailureReason>.success(node(extra: gpus)), 0)])
    #expect(tracker.history.elements.last?.vram == 0.8)
    #expect(tracker.history.elements.last?.gpuBusy == 0.5)
  }
}
