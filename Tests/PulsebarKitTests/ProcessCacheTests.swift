import PulsebarKit
import Testing

struct ProcessCacheTests {
  private let first = ProcessID(pid: 42, startTime: 1)
  private let reused = ProcessID(pid: 42, startTime: 2)

  @Test func computesOncePerProcess() {
    var cache = ProcessCache<String>()
    var calls = 0
    for _ in 1...3 {
      let value = cache.value(for: first) {
        calls += 1
        return "node \(calls)"
      }
      #expect(value == "node 1")
    }
    #expect(calls == 1)
  }

  @Test func whenPidIsReusedComputesAgain() {
    var cache = ProcessCache<String>()
    _ = cache.value(for: first) { "zsh" }
    #expect(cache.value(for: reused) { "node" } == "node")
  }

  @Test func retriesMissingValues() {
    var cache = ProcessCache<String>()
    _ = cache.value(for: first) { nil }
    #expect(cache.value(for: first) { "node" } == "node")
  }

  @Test func retainDropsExitedProcesses() {
    var cache = ProcessCache<String>()
    _ = cache.value(for: first) { "zsh" }
    _ = cache.value(for: reused) { "node" }
    cache.retain([reused])
    #expect(cache.value(for: first) { "bun" } == "bun")
    #expect(cache.value(for: reused) { "bun" } == "node")
  }

  @Test func retainWithNoIdsEmptiesCache() {
    var cache = ProcessCache<String>()
    _ = cache.value(for: first) { "zsh" }
    cache.retain([])
    #expect(cache.value(for: first) { "bun" } == "bun")
  }
}
