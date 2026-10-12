import PulsebarKit
import Testing

struct TopAppsTests {
  @Test func sumsValuesAndCountsProcessesPerApp() {
    let ranked = TopApps.rank(
      [(app: "Firefox", value: 300), (app: "node", value: 50), (app: "Firefox", value: 200)],
      limit: 6)
    #expect(
      ranked == [
        AppUsage(name: "Firefox", processCount: 2, total: 500),
        AppUsage(name: "node", processCount: 1, total: 50),
      ])
  }

  @Test func keepsOnlyTopLimitByTotal() {
    let entries: [(app: String, value: UInt64)] = (1...10).map { (app: "app\($0)", value: $0) }
    #expect(TopApps.rank(entries, limit: 3).map(\.name) == ["app10", "app9", "app8"])
  }

  @Test func withTiesOrdersByName() {
    let ranked = TopApps.rank(
      [(app: "zsh", value: 7.5), (app: "bun", value: 7.5), (app: "claude", value: 9.0)], limit: 5)
    #expect(ranked.map(\.name) == ["claude", "bun", "zsh"])
  }

  @Test func withFewerAppsThanLimitReturnsAll() {
    #expect(TopApps.rank([(app: "bun", value: 1)], limit: 6).count == 1)
  }

  @Test func withoutEntriesIsEmpty() {
    #expect(TopApps.rank([(app: String, value: Double)](), limit: 5).isEmpty)
  }

  @Test func withNonPositiveLimitIsEmpty() {
    #expect(TopApps.rank([(app: "bun", value: 1)], limit: -1).isEmpty)
  }
}
