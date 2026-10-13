import PulsebarKit
import Testing

struct NodeMetricsTests {
  private func metrics(_ body: String) -> NodeMetrics {
    NodeMetrics(samples: PrometheusText.parse(Array(body.utf8)))
  }

  @Test func withFullBodySumsBusyAndTotalTicks() {
    #expect(metrics(NodeExporterSample.withDRM).cpu == NodeCPUTicks(busy: 8115, total: 23415))
  }

  @Test func withFullBodyCountsDistinctCPUs() {
    #expect(metrics(NodeExporterSample.withDRM).cores == 2)
  }

  @Test func withFullBodyIsNodeExporter() {
    #expect(metrics(NodeExporterSample.withDRM).isNodeExporter)
  }

  @Test func withFullBodyReadsMemoryUsedAndTotal() {
    let node = metrics(NodeExporterSample.withDRM)
    #expect(node.memoryUsed == 6_000_000_000)
    #expect(node.memoryTotal == 8_000_000_000)
    #expect(node.memoryFraction == 0.75)
  }

  @Test func withFullBodyReadsSwapUsedAndTotal() {
    let node = metrics(NodeExporterSample.withDRM)
    #expect(node.swapUsed == 1_500_000_000)
    #expect(node.swapTotal == 2_000_000_000)
  }

  @Test func withFullBodyReadsLoadAverages() {
    let node = metrics(NodeExporterSample.withDRM)
    #expect(node.load1 == 3.2)
    #expect(node.load5 == 2.8)
    #expect(node.load15 == 2.1)
  }

  @Test func withFullBodyUptimeIsNowMinusBoot() {
    #expect(metrics(NodeExporterSample.withDRM).uptime == 86_400.5)
  }

  @Test func withFullBodyReadsRootFilesystemOnly() {
    let node = metrics(NodeExporterSample.withDRM)
    #expect(node.rootAvailable == 50_000_000_000)
    #expect(node.rootSize == 100_000_000_000)
  }

  @Test func withFullBodyExcludesVirtualInterfaces() {
    let node = metrics(NodeExporterSample.withDRM)
    #expect(node.networkReceived == 300)
    #expect(node.networkTransmitted == 30)
  }

  @Test func withFullBodyReadsGPUsSortedByCard() {
    let gpus = metrics(NodeExporterSample.withDRM).gpus
    #expect(gpus.map(\.card) == ["card0", "card1"])
    #expect(gpus[0].vramUsed == 4_000_000_000)
    #expect(gpus[0].vramSize == 8_000_000_000)
    #expect(gpus[0].gttUsed == 200_000_000)
    #expect(gpus[0].gttSize == 16_000_000_000)
    #expect(gpus[0].busyFraction == 0.42)
    #expect(gpus[0].vramFraction == 0.5)
  }

  @Test func withFullBodyPicksFullestGPU() {
    #expect(metrics(NodeExporterSample.withDRM).fullestGPU?.card == "card1")
  }

  @Test func withoutDRMHasNoGPUs() {
    let node = metrics(NodeExporterSample.withoutDRM)
    #expect(node.gpus.isEmpty)
    #expect(node.fullestGPU == nil)
    #expect(node.isNodeExporter)
  }

  @Test func withoutCPUMetricIsNotNodeExporter() {
    let node = NodeMetrics(samples: [MetricSample(name: "node_load1", value: 1)])
    #expect(!node.isNodeExporter)
    #expect(node.cpu == nil)
    #expect(node.cores == nil)
  }

  @Test func withMissingMetricsReadsNil() {
    let node = NodeMetrics(samples: [MetricSample(name: "node_load1", value: 1.5)])
    #expect(node.load1 == 1.5)
    #expect(node.load5 == nil)
    #expect(node.memoryUsed == nil)
    #expect(node.memoryFraction == nil)
    #expect(node.uptime == nil)
    #expect(node.rootAvailable == nil)
    #expect(node.networkReceived == nil)
  }

  @Test func whenMemAvailableMissingMemoryUsedIsNil() {
    let node = NodeMetrics(samples: [
      MetricSample(name: "node_memory_MemTotal_bytes", value: 8_000_000_000)
    ])
    #expect(node.memoryUsed == nil)
    #expect(node.memoryTotal == 8_000_000_000)
  }

  @Test func whenAvailableExceedsTotalMemoryIsZero() {
    let node = NodeMetrics(samples: [
      MetricSample(name: "node_memory_MemTotal_bytes", value: 100),
      MetricSample(name: "node_memory_MemAvailable_bytes", value: 200),
    ])
    #expect(node.memoryUsed == 0)
  }

  @Test func whenValueIsNaNOrNegativeReadsNil() {
    let node = NodeMetrics(samples: [
      MetricSample(name: "node_memory_MemTotal_bytes", value: .nan),
      MetricSample(name: "node_memory_SwapTotal_bytes", value: -1),
    ])
    #expect(node.memoryTotal == nil)
    #expect(node.swapTotal == nil)
  }

  @Test func whenOnlyVirtualInterfacesNetworkIsNil() {
    let node = NodeMetrics(samples: [
      MetricSample(name: "node_network_receive_bytes_total", labels: ["device": "veth1"], value: 5),
      MetricSample(name: "node_network_receive_bytes_total", labels: ["device": "lo"], value: 5),
    ])
    #expect(node.networkReceived == nil)
  }

  @Test func whenFilesystemMountIsNotRootRootIsNil() {
    let node = NodeMetrics(samples: [
      MetricSample(
        name: "node_filesystem_size_bytes", labels: ["mountpoint": "/boot"], value: 500_000_000)
    ])
    #expect(node.rootSize == nil)
  }
}

struct NodeCPUTicksTests {
  private let before = NodeCPUTicks(busy: 100, total: 1000)

  @Test func busyFractionIsBusyDeltaOverTotalDelta() {
    #expect(NodeCPUTicks(busy: 160, total: 1100).busyFraction(since: before) == 0.6)
  }

  @Test func withoutElapsedTicksIsNil() {
    #expect(before.busyFraction(since: before) == nil)
  }

  @Test func whenBusyDecreasesIsNil() {
    #expect(NodeCPUTicks(busy: 90, total: 1100).busyFraction(since: before) == nil)
  }

  @Test func whenTotalDecreasesIsNil() {
    #expect(NodeCPUTicks(busy: 150, total: 900).busyFraction(since: before) == nil)
  }
}

struct NodeRatesTests {
  private func reading(busy: Double, total: Double, received: Double, transmitted: Double)
    -> NodeMetrics
  {
    NodeMetrics(samples: [
      MetricSample(
        name: "node_cpu_seconds_total", labels: ["cpu": "0", "mode": "user"], value: busy),
      MetricSample(
        name: "node_cpu_seconds_total", labels: ["cpu": "0", "mode": "idle"], value: total - busy),
      MetricSample(
        name: "node_network_receive_bytes_total", labels: ["device": "eth0"], value: received),
      MetricSample(
        name: "node_network_transmit_bytes_total", labels: ["device": "eth0"], value: transmitted),
    ])
  }

  @Test func withTwoReadingsComputesCPUAndRates() {
    let previous = reading(busy: 100, total: 1000, received: 1000, transmitted: 500)
    let current = reading(busy: 300, total: 1400, received: 3000, transmitted: 1500)
    let rates = NodeRates(current: current, previous: previous, interval: 2)
    #expect(rates.cpuFraction == 0.5)
    #expect(rates.downRate == 1000)
    #expect(rates.upRate == 500)
  }

  @Test func whenCounterResetsReadsNil() {
    let previous = reading(busy: 100, total: 1000, received: 1000, transmitted: 500)
    let current = reading(busy: 10, total: 1100, received: 10, transmitted: 600)
    let rates = NodeRates(current: current, previous: previous, interval: 2)
    #expect(rates.cpuFraction == nil)
    #expect(rates.downRate == nil)
    #expect(rates.upRate == 50)
  }

  @Test func withoutPreviousReadingAllNil() {
    let current = reading(busy: 300, total: 1400, received: 3000, transmitted: 1500)
    let rates = NodeRates(current: current, previous: nil, interval: 2)
    #expect(rates.cpuFraction == nil)
    #expect(rates.downRate == nil)
    #expect(rates.upRate == nil)
  }
}
