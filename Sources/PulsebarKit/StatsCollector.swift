import Foundation

public actor StatsCollector {
  private let memory = MemorySampler()
  private var processes = ProcessSampler()
  private var cpu = CPUSampler()
  private var disk = DiskSampler()
  private var network = NetworkSampler()

  public init() {}

  public func sample() -> Stats {
    let now = ProcessInfo.processInfo.systemUptime
    return Stats(
      memory: memory.sample(),
      apps: processes.sample(at: now),
      cpuFraction: cpu.sample(),
      disk: disk.sample(at: now),
      network: network.sample(at: now)
    )
  }
}
