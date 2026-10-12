public struct AppUsage<Value: Numeric & Comparable & Sendable>: Equatable, Sendable {
  public let name: String
  public let processCount: Int
  public let total: Value

  public init(name: String, processCount: Int, total: Value) {
    self.name = name
    self.processCount = processCount
    self.total = total
  }
}

public enum TopApps {
  public static func rank<Value>(_ entries: [(app: String, value: Value)], limit: Int)
    -> [AppUsage<Value>]
  {
    let usages = Dictionary(grouping: entries, by: \.app).map { name, group in
      AppUsage(name: name, processCount: group.count, total: group.map(\.value).reduce(0, +))
    }
    let ranked = usages.sorted { lhs, rhs in
      lhs.total == rhs.total ? lhs.name < rhs.name : lhs.total > rhs.total
    }
    return Array(ranked.prefix(max(limit, 0)))
  }
}
