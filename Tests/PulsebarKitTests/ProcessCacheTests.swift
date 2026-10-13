import PulsebarKit
import Testing

struct ProcessCacheTests {
  private let first = ProcessID(pid: 42, startTime: 1)
  private let reused = ProcessID(pid: 42, startTime: 2)

  @Test func computesOncePerProcess() {
    var cache = ProcessCache<String>()
    var calls = 0
    for _ in 1...3 {
      _ = cache.value(for: first) {
        calls += 1
        return "node"
      }
    }
    #expect(calls == 1)
  }

  @Test func returnsTheFirstValue() {
    var cache = ProcessCache<String>()
    _ = cache.value(for: first) { "zsh" }
    #expect(cache.value(for: first) { "node" } == "zsh")
  }

  @Test func whenPidIsReusedComputesAgain() {
    var cache = ProcessCache<String>()
    _ = cache.value(for: first) { "zsh" }
    #expect(cache.value(for: reused) { "node" } == "node")
  }

  @Test func cachesMissingValues() {
    var cache = ProcessCache<String?>()
    var calls = 0
    for _ in 1...2 {
      _ = cache.value(for: first) {
        calls += 1
        return nil
      }
    }
    #expect(calls == 1)
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
