public struct HistorySample: Sendable {
  public let pressureFraction: Double?
  public let pressure: PressureLevel?
  public let cpuFraction: Double?
  public let diskRead: Double?
  public let diskWrite: Double?
  public let networkDown: Double?
  public let networkUp: Double?

  public init(_ stats: Stats) {
    pressureFraction = stats.memory.map { Double(100 - $0.availablePercent) / 100 }
    pressure = stats.memory?.pressure
    cpuFraction = stats.cpuFraction
    diskRead = stats.disk.readRate
    diskWrite = stats.disk.writeRate
    networkDown = stats.network.downRate
    networkUp = stats.network.upRate
  }
}
