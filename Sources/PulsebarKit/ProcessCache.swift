public struct ProcessCache<Value> {
  private var values: [ProcessID: Value] = [:]

  public init() {}

  public mutating func value(for id: ProcessID, _ make: () -> Value) -> Value {
    if let value = values[id] { return value }
    let value = make()
    values[id] = value
    return value
  }

  public mutating func retain(_ ids: Set<ProcessID>) {
    values = values.filter { ids.contains($0.key) }
  }
}

extension ProcessCache: Sendable where Value: Sendable {}
