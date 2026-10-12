public enum PressureLevel: Sendable {
  case normal, warning, critical
}

public struct MemoryStats: Sendable {
  public let pressure: PressureLevel
  public let availablePercent: Int
  public let breakdown: MemoryBreakdown
  public let total: UInt64
  public let swapUsed: UInt64
  public let swapTotal: UInt64

  public var usedFraction: Double { Double(breakdown.used) / Double(total) }
}

public struct ProcessStats: Sendable {
  public let topMemory: [AppUsage<UInt64>]
  public let topCPU: [AppUsage<Double>]
}

public struct DiskSpace: Sendable {
  public let available: Int64
  public let total: Int64
}

public struct DiskStats: Sendable {
  public let space: DiskSpace?
  public let readRate: Double?
  public let writeRate: Double?
}

public struct NetworkStats: Sendable {
  public let downRate: Double?
  public let upRate: Double?
}

public struct Stats: Sendable {
  public let memory: MemoryStats?
  public let processes: ProcessStats
  public let cpuFraction: Double?
  public let disk: DiskStats
  public let network: NetworkStats
}
