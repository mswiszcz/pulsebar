import Foundation

public struct DockerContainer: Equatable, Sendable {
  public let id: String
  public let name: String
}

public struct DockerStatsSample: Equatable, Sendable {
  public let memory: UInt64
  public let cpuTotal: UInt64
  public let systemTotal: UInt64?
  public let onlineCPUs: Int?
}

public struct ContainerUsage: Equatable, Sendable {
  public let name: String
  public let memory: UInt64
  public let cpuShare: Double?

  public init(name: String, memory: UInt64, cpuShare: Double?) {
    self.name = name
    self.memory = memory
    self.cpuShare = cpuShare
  }
}

public enum DockerAPI {
  private struct ContainerSummary: Decodable {
    let id: String
    let names: [String]?

    enum CodingKeys: String, CodingKey {
      case id = "Id"
      case names = "Names"
    }
  }

  private struct StatsPayload: Decodable {
    struct CPU: Decodable {
      struct Usage: Decodable {
        let totalUsage: UInt64

        enum CodingKeys: String, CodingKey {
          case totalUsage = "total_usage"
        }
      }

      let usage: Usage
      let systemUsage: UInt64?
      let onlineCPUs: Int?

      enum CodingKeys: String, CodingKey {
        case usage = "cpu_usage"
        case systemUsage = "system_cpu_usage"
        case onlineCPUs = "online_cpus"
      }
    }

    struct Memory: Decodable {
      let usage: UInt64?
      let stats: [String: UInt64]?
    }

    let cpu: CPU
    let memory: Memory

    enum CodingKeys: String, CodingKey {
      case cpu = "cpu_stats"
      case memory = "memory_stats"
    }
  }

  public static func containers(fromJSON json: [UInt8]) -> [DockerContainer]? {
    guard let summaries = try? JSONDecoder().decode([ContainerSummary].self, from: Data(json))
    else {
      return nil
    }
    return summaries.map { summary in
      let name = summary.names?.first.map { $0.hasPrefix("/") ? String($0.dropFirst()) : $0 }
      return DockerContainer(id: summary.id, name: name ?? String(summary.id.prefix(12)))
    }
  }

  public static func stats(fromJSON json: [UInt8]) -> DockerStatsSample? {
    guard let payload = try? JSONDecoder().decode(StatsPayload.self, from: Data(json)) else {
      return nil
    }
    let usage = payload.memory.usage ?? 0
    let stats = payload.memory.stats ?? [:]
    let cache = stats["inactive_file"] ?? stats["total_inactive_file"] ?? 0
    return DockerStatsSample(
      memory: cache < usage ? usage - cache : usage,
      cpuTotal: payload.cpu.usage.totalUsage,
      systemTotal: payload.cpu.systemUsage,
      onlineCPUs: payload.cpu.onlineCPUs
    )
  }

  public static func cpuShare(
    previous: DockerStatsSample?, current: DockerStatsSample, hostCores: Int
  ) -> Double? {
    guard let previous, let currentSystem = current.systemTotal,
      let previousSystem = previous.systemTotal, let onlineCPUs = current.onlineCPUs,
      hostCores > 0, currentSystem > previousSystem, current.cpuTotal >= previous.cpuTotal
    else { return nil }
    let busy = Double(current.cpuTotal - previous.cpuTotal)
    let elapsed = Double(currentSystem - previousSystem) / Double(onlineCPUs)
    return busy / elapsed / Double(hostCores)
  }
}
