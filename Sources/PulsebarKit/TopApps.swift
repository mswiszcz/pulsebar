public struct ProcessID: Hashable, Sendable {
  public let pid: Int32
  public let startTime: UInt64

  public init(pid: Int32, startTime: UInt64) {
    self.pid = pid
    self.startTime = startTime
  }
}

public struct ProcessUsage: Sendable {
  public let id: ProcessID
  public let app: AppIdentity
  public let memory: UInt64
  public let cpuShare: Double?

  public init(id: ProcessID, app: AppIdentity, memory: UInt64, cpuShare: Double?) {
    self.id = id
    self.app = app
    self.memory = memory
    self.cpuShare = cpuShare
  }
}

public struct AppUsage: Equatable, Sendable {
  public let app: AppIdentity
  public let processCount: Int
  public let memory: UInt64
  public let cpuShare: Double?

  public init(app: AppIdentity, processCount: Int, memory: UInt64, cpuShare: Double?) {
    self.app = app
    self.processCount = processCount
    self.memory = memory
    self.cpuShare = cpuShare
  }
}

public enum TopApps {
  public static func aggregate(_ processes: [ProcessUsage]) -> [AppUsage] {
    Dictionary(grouping: processes, by: \.app).map { app, group in
      let shares = group.compactMap(\.cpuShare)
      return AppUsage(
        app: app,
        processCount: group.count,
        memory: group.map(\.memory).reduce(0, +),
        cpuShare: shares.isEmpty ? nil : shares.reduce(0, +)
      )
    }
  }

  public static func culprits(_ apps: [AppUsage], byMemory: Int, byCPU: Int) -> [AppUsage] {
    let memoryLeaders = apps.sorted(by: memoryOrder).prefix(max(byMemory, 0))
    let cpuLeaders = apps.filter { ($0.cpuShare ?? 0) > 0 }
      .sorted { lhs, rhs in
        lhs.cpuShare == rhs.cpuShare
          ? lhs.app.name < rhs.app.name : (lhs.cpuShare ?? 0) > (rhs.cpuShare ?? 0)
      }
      .prefix(max(byCPU, 0))
    let memoryApps = Set(memoryLeaders.map(\.app))
    return (memoryLeaders + cpuLeaders.filter { !memoryApps.contains($0.app) })
      .sorted(by: memoryOrder)
  }

  public static func topProcesses(
    _ processes: [ProcessUsage], of app: AppIdentity, limit: Int
  ) -> [ProcessUsage] {
    let ranked = processes.filter { $0.app == app }.sorted { lhs, rhs in
      lhs.memory == rhs.memory ? lhs.id.pid < rhs.id.pid : lhs.memory > rhs.memory
    }
    return Array(ranked.prefix(max(limit, 0)))
  }

  private static func memoryOrder(_ lhs: AppUsage, _ rhs: AppUsage) -> Bool {
    lhs.memory == rhs.memory ? lhs.app.name < rhs.app.name : lhs.memory > rhs.memory
  }
}
