import PulsebarKit
import Testing

struct RingBufferTests {
  @Test func belowCapacityKeepsAppendOrder() {
    var buffer = RingBuffer<Int>(capacity: 3)
    buffer.append(1)
    buffer.append(2)
    #expect(buffer.elements == [1, 2])
  }

  @Test func whenFullDropsOldestFirst() {
    var buffer = RingBuffer<Int>(capacity: 3)
    for value in 1...7 { buffer.append(value) }
    #expect(buffer.elements == [5, 6, 7])
  }

  @Test func withoutAppendsIsEmpty() {
    #expect(RingBuffer<Int>(capacity: 3).elements.isEmpty)
  }

  @Test(arguments: [0, -2])
  func withNoCapacityStoresNothing(capacity: Int) {
    var buffer = RingBuffer<Int>(capacity: capacity)
    buffer.append(1)
    #expect(buffer.elements.isEmpty)
  }

  @Test func withCapacityOneKeepsLatest() {
    var buffer = RingBuffer<Int>(capacity: 1)
    buffer.append(1)
    buffer.append(2)
    #expect(buffer.elements == [2])
  }
}
