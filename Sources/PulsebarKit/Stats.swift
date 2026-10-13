import Foundation

public enum PressureLevel: Comparable, Sendable {
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

public struct ProcessDetail: Equatable, Sendable {
  public let id: ProcessID
  public let label: String
  public let memory: UInt64
  public let cpuShare: Double?
  public let started: Date?
}

public struct ProcessSnapshot: Sendable {
  public let apps: [AppUsage]
  public let largeApps: [AppIdentity: UInt64]
  public let details: [AppIdentity: [ProcessDetail]]
}

public struct Stats: Sendable {
  public let memory: MemoryStats?
  public let processes: ProcessSnapshot
  public let cpuFraction: Double?
  public let disk: DiskStats
  public let network: NetworkStats

  public var apps: [AppUsage] { processes.apps }
}
