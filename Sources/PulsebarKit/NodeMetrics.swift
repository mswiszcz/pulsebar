public struct NodeCPUTicks: Equatable, Sendable {
  public let busy: Double
  public let total: Double

  public init(busy: Double, total: Double) {
    self.busy = busy
    self.total = total
  }

  public func busyFraction(since previous: NodeCPUTicks) -> Double? {
    guard busy >= previous.busy, total >= previous.total else { return nil }
    let totalDelta = total - previous.total
    return totalDelta > 0 ? (busy - previous.busy) / totalDelta : nil
  }
}

public struct GPUReading: Equatable, Sendable {
  public let card: String
  public let vramUsed: UInt64?
  public let vramSize: UInt64?
  public let gttUsed: UInt64?
  public let gttSize: UInt64?
  public let busyFraction: Double?

  public var vramFraction: Double? {
    guard let vramUsed, let vramSize, vramSize > 0 else { return nil }
    return Double(vramUsed) / Double(vramSize)
  }
}

public struct NodeMetrics: Equatable, Sendable {
  public let cpu: NodeCPUTicks?
  public let cores: Int?
  public let memoryUsed: UInt64?
  public let memoryTotal: UInt64?
  public let swapUsed: UInt64?
  public let swapTotal: UInt64?
  public let load1: Double?
  public let load5: Double?
  public let load15: Double?
  public let uptime: Double?
  public let rootAvailable: UInt64?
  public let rootSize: UInt64?
  public let networkReceived: UInt64?
  public let networkTransmitted: UInt64?
  public let gpus: [GPUReading]

  public init(samples: [MetricSample]) {
    let cpuSamples = samples.filter { $0.name == "node_cpu_seconds_total" }
    cpu = Self.cpuTicks(cpuSamples)
    cores = cpuSamples.isEmpty ? nil : Set(cpuSamples.compactMap { $0.labels["cpu"] }).count
    memoryUsed = Self.usedBytes(
      samples, total: "node_memory_MemTotal_bytes", free: "node_memory_MemAvailable_bytes")
    memoryTotal = Self.bytes(Self.scalar(samples, "node_memory_MemTotal_bytes"))
    swapUsed = Self.usedBytes(
      samples, total: "node_memory_SwapTotal_bytes", free: "node_memory_SwapFree_bytes")
    swapTotal = Self.bytes(Self.scalar(samples, "node_memory_SwapTotal_bytes"))
    load1 = Self.scalar(samples, "node_load1")
    load5 = Self.scalar(samples, "node_load5")
    load15 = Self.scalar(samples, "node_load15")
    uptime = Self.uptime(samples)
    rootAvailable = Self.bytes(Self.root(samples, "node_filesystem_avail_bytes"))
    rootSize = Self.bytes(Self.root(samples, "node_filesystem_size_bytes"))
    networkReceived = Self.networkBytes(samples, "node_network_receive_bytes_total")
    networkTransmitted = Self.networkBytes(samples, "node_network_transmit_bytes_total")
    gpus = Self.gpuReadings(samples)
  }

  public var isNodeExporter: Bool { cpu != nil }

  public var memoryFraction: Double? {
    guard let memoryUsed, let memoryTotal, memoryTotal > 0 else { return nil }
    return Double(memoryUsed) / Double(memoryTotal)
  }

  public var fullestGPU: GPUReading? {
    gpus.max { ($0.vramFraction ?? -1) < ($1.vramFraction ?? -1) }
  }

  private static let idleModes: Set<String> = ["idle", "iowait"]
  private static let virtualDevicePrefixes = ["veth", "docker", "br-", "virbr"]
  private static let gpuMetricNames: Set<String> = [
    "node_drm_memory_vram_used_bytes",
    "node_drm_memory_vram_size_bytes",
    "node_drm_memory_gtt_used_bytes",
    "node_drm_memory_gtt_size_bytes",
    "node_drm_gpu_busy_percent",
  ]

  private static func cpuTicks(_ samples: [MetricSample]) -> NodeCPUTicks? {
    guard !samples.isEmpty else { return nil }
    let busy = samples.filter { !idleModes.contains($0.labels["mode"] ?? "") }
      .reduce(0) { $0 + $1.value }
    let total = samples.reduce(0) { $0 + $1.value }
    return NodeCPUTicks(busy: busy, total: total)
  }

  private static func scalar(_ samples: [MetricSample], _ name: String) -> Double? {
    samples.first { $0.name == name }?.value
  }

  private static func root(_ samples: [MetricSample], _ name: String) -> Double? {
    samples.first { $0.name == name && $0.labels["mountpoint"] == "/" }?.value
  }

  private static func uptime(_ samples: [MetricSample]) -> Double? {
    guard let now = scalar(samples, "node_time_seconds"),
      let boot = scalar(samples, "node_boot_time_seconds")
    else { return nil }
    return now - boot
  }

  private static func usedBytes(_ samples: [MetricSample], total: String, free: String) -> UInt64? {
    guard let totalValue = scalar(samples, total), let freeValue = scalar(samples, free) else {
      return nil
    }
    return bytes(max(totalValue - freeValue, 0))
  }

  private static func networkBytes(_ samples: [MetricSample], _ name: String) -> UInt64? {
    let devices = samples.filter { $0.name == name && isPhysical($0.labels["device"] ?? "") }
    guard !devices.isEmpty else { return nil }
    return bytes(devices.reduce(0) { $0 + $1.value })
  }

  private static func isPhysical(_ device: String) -> Bool {
    device != "lo" && !virtualDevicePrefixes.contains { device.hasPrefix($0) }
  }

  private static func gpuReadings(_ samples: [MetricSample]) -> [GPUReading] {
    let cards = Set(
      samples.filter { gpuMetricNames.contains($0.name) }.compactMap { $0.labels["card"] })
    return cards.sorted().map { card in
      func value(_ name: String) -> Double? {
        samples.first { $0.name == name && $0.labels["card"] == card }?.value
      }
      return GPUReading(
        card: card,
        vramUsed: bytes(value("node_drm_memory_vram_used_bytes")),
        vramSize: bytes(value("node_drm_memory_vram_size_bytes")),
        gttUsed: bytes(value("node_drm_memory_gtt_used_bytes")),
        gttSize: bytes(value("node_drm_memory_gtt_size_bytes")),
        busyFraction: value("node_drm_gpu_busy_percent").map { $0 / 100 })
    }
  }

  private static func bytes(_ value: Double?) -> UInt64? {
    guard let value, value.isFinite, value >= 0, value < Double(UInt64.max) else { return nil }
    return UInt64(value)
  }
}

public struct NodeRates: Equatable, Sendable {
  public let cpuFraction: Double?
  public let downRate: Double?
  public let upRate: Double?

  public init(current: NodeMetrics, previous: NodeMetrics?, interval: Double) {
    cpuFraction = current.cpu.flatMap { cpu in previous?.cpu.flatMap { cpu.busyFraction(since: $0) }
    }
    downRate = Self.rate(current.networkReceived, previous?.networkReceived, interval)
    upRate = Self.rate(current.networkTransmitted, previous?.networkTransmitted, interval)
  }

  private static func rate(_ current: UInt64?, _ previous: UInt64?, _ interval: Double) -> Double? {
    guard let current else { return nil }
    return CounterRate.perSecond(previous: previous, current: current, interval: interval)
  }
}
