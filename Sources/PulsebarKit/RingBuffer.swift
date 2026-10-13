public struct RingBuffer<Element> {
  public let capacity: Int
  private var storage: [Element] = []
  private var head = 0

  public init(capacity: Int) {
    self.capacity = max(capacity, 0)
  }

  public var elements: [Element] {
    Array(storage[head...] + storage[..<head])
  }

  public mutating func append(_ element: Element) {
    guard capacity > 0 else { return }
    if storage.count < capacity {
      storage.append(element)
    } else {
      storage[head] = element
      head = (head + 1) % capacity
    }
  }
}

extension RingBuffer: Sendable where Element: Sendable {}
