import PulsebarKit
import Testing

struct MemoryGrowthTests {
  private let firefox = AppIdentity(name: "Firefox", bundlePath: "/Applications/Firefox.app")
  private let docker = AppIdentity(name: "Docker", bundlePath: "/Applications/Docker.app")
  private let threshold: UInt64 = 500

  @Test func reportsGrowthFromOldestSnapshot() {
    let growth = MemoryGrowth.growth(
      snapshots: [[firefox: 1_000], [firefox: 1_200], [firefox: 1_700]], threshold: threshold)
    #expect(growth == [firefox: 700])
  }

  @Test func exactlyAtThresholdCounts() {
    #expect(
      MemoryGrowth.growth(snapshots: [[firefox: 100], [firefox: 600]], threshold: threshold)
        == [firefox: 500])
  }

  @Test func belowThresholdIsIgnored() {
    #expect(
      MemoryGrowth.growth(snapshots: [[firefox: 100], [firefox: 599]], threshold: threshold)
        .isEmpty)
  }

  @Test func newAppMeasuresFromFirstAppearance() {
    let growth = MemoryGrowth.growth(
      snapshots: [
        [firefox: 1_000], [firefox: 1_000, docker: 200], [firefox: 1_000, docker: 900],
      ],
      threshold: threshold)
    #expect(growth == [docker: 700])
  }

  @Test func disappearedAppIsIgnored() {
    #expect(
      MemoryGrowth.growth(snapshots: [[docker: 100], [docker: 900], [:]], threshold: threshold)
        .isEmpty)
  }

  @Test func shrinkingAppIsIgnored() {
    #expect(
      MemoryGrowth.growth(snapshots: [[firefox: 2_000], [firefox: 100]], threshold: threshold)
        .isEmpty)
  }

  @Test func withoutSnapshotsIsEmpty() {
    #expect(MemoryGrowth.growth(snapshots: [], threshold: threshold).isEmpty)
  }

  @Test func snapshotKeepsAppsAtOrAboveMinimum() {
    let apps = [
      AppUsage(app: firefox, processCount: 1, memory: 100, cpuShare: nil),
      AppUsage(app: docker, processCount: 1, memory: 99, cpuShare: nil),
    ]
    #expect(MemoryGrowth.snapshot(apps, minimum: 100) == [firefox: 100])
  }
}
