import PulsebarKit
import Testing

struct TopAppsTests {
  private let firefox = AppIdentity(name: "Firefox", bundlePath: "/Applications/Firefox.app")
  private let node = AppIdentity(name: "node", bundlePath: nil)

  private func app(_ name: String, memory: UInt64, cpu: Double? = 0) -> AppUsage {
    AppUsage(
      app: AppIdentity(name: name, bundlePath: nil), processCount: 1, memory: memory,
      cpuShare: cpu)
  }

  @Test func aggregateSumsMemoryCPUAndCountsPerApp() {
    let apps = TopApps.aggregate([
      ProcessUsage(app: firefox, memory: 300, cpuShare: 0.25),
      ProcessUsage(app: node, memory: 50, cpuShare: 0.01),
      ProcessUsage(app: firefox, memory: 200, cpuShare: 0.5),
    ])
    #expect(
      Set(apps.map(\.app.name)) == ["Firefox", "node"]
        && apps.contains(AppUsage(app: firefox, processCount: 2, memory: 500, cpuShare: 0.75)))
  }

  @Test func aggregateWithoutCPUBaselineHasNoShare() {
    let apps = TopApps.aggregate([
      ProcessUsage(app: node, memory: 10, cpuShare: nil),
      ProcessUsage(app: node, memory: 20, cpuShare: nil),
    ])
    #expect(apps == [AppUsage(app: node, processCount: 2, memory: 30, cpuShare: nil)])
  }

  @Test func aggregateSumsOnlyProcessesWithBaseline() {
    let apps = TopApps.aggregate([
      ProcessUsage(app: node, memory: 10, cpuShare: nil),
      ProcessUsage(app: node, memory: 20, cpuShare: 0.125),
    ])
    #expect(apps.first?.cpuShare == 0.125)
  }

  @Test func aggregateKeepsSameNameDifferentBundlesApart() {
    let other = AppIdentity(name: "Firefox", bundlePath: "/Users/me/Firefox.app")
    let apps = TopApps.aggregate([
      ProcessUsage(app: firefox, memory: 1, cpuShare: 0),
      ProcessUsage(app: other, memory: 1, cpuShare: 0),
    ])
    #expect(apps.count == 2)
  }

  @Test func aggregateWithoutProcessesIsEmpty() {
    #expect(TopApps.aggregate([]).isEmpty)
  }

  @Test func culpritsAddCPULeadersSortedByMemory() {
    let apps =
      (1...8).map { app("mem\($0)", memory: UInt64($0) * 100) } + [
        app("busy", memory: 10, cpu: 0.9)
      ]
    #expect(
      TopApps.culprits(apps, byMemory: 6, byCPU: 3).map(\.app.name) == [
        "mem8", "mem7", "mem6", "mem5", "mem4", "mem3", "busy",
      ])
  }

  @Test func culpritsListAppLeadingBothOnce() {
    let apps = [app("Firefox", memory: 900, cpu: 0.8), app("node", memory: 100)]
    #expect(TopApps.culprits(apps, byMemory: 6, byCPU: 3).map(\.app.name) == ["Firefox", "node"])
  }

  @Test func culpritsSkipIdleAppsForCPU() {
    let apps = [app("a", memory: 30), app("b", memory: 20), app("c", memory: 10, cpu: nil)]
    #expect(TopApps.culprits(apps, byMemory: 1, byCPU: 3).map(\.app.name) == ["a"])
  }

  @Test func culpritsKeepOnlyTopCPULeaders() {
    let apps = (1...5).map { app("cpu\($0)", memory: 1, cpu: Double($0) / 10) }
    #expect(
      TopApps.culprits(apps, byMemory: 0, byCPU: 2).map(\.app.name) == ["cpu4", "cpu5"])
  }

  @Test func culpritsWithTiesOrderByName() {
    let apps = [app("zsh", memory: 5), app("bun", memory: 5), app("claude", memory: 9)]
    #expect(
      TopApps.culprits(apps, byMemory: 6, byCPU: 3).map(\.app.name) == ["claude", "bun", "zsh"])
  }

  @Test func culpritsWithNonPositiveLimitsAreEmpty() {
    #expect(TopApps.culprits([app("a", memory: 1, cpu: 0.5)], byMemory: -1, byCPU: 0).isEmpty)
  }
}
