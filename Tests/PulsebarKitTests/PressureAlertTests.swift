import PulsebarKit
import Testing

struct PressureAlertTests {
  private let firefox = AppIdentity(name: "Firefox", bundlePath: "/Applications/Firefox.app")
  private let docker = AppIdentity(name: "Docker", bundlePath: "/Applications/Docker.app")
  private let gigabyte: UInt64 = 1_073_741_824

  private func gigabytes(_ bytes: UInt64) -> String {
    "\(bytes / gigabyte) GB"
  }

  @Test func namesBiggestGrower() {
    let alert = PressureAlert(
      level: .warning, growth: [firefox: 3 * gigabyte, docker: gigabyte], growthMinutes: 10,
      apps: [AppUsage(app: docker, processCount: 1, memory: 6 * gigabyte, cpuShare: nil)],
      formatBytes: gigabytes)
    #expect(alert.title == "Memory under pressure")
    #expect(alert.body == "Firefox grew 3 GB in 10 min")
  }

  @Test func withoutGrowerNamesBiggestApp() {
    let alert = PressureAlert(
      level: .critical, growth: [:], growthMinutes: 10,
      apps: [
        AppUsage(app: firefox, processCount: 1, memory: gigabyte, cpuShare: nil),
        AppUsage(app: docker, processCount: 1, memory: 6 * gigabyte, cpuShare: nil),
      ],
      formatBytes: gigabytes)
    #expect(alert.title == "Memory critical")
    #expect(alert.body == "Docker uses 6 GB")
  }

  @Test func withoutAppsHasOnlyTitle() {
    let alert = PressureAlert(
      level: .warning, growth: [:], growthMinutes: 10, apps: [], formatBytes: gigabytes)
    #expect(alert.title == "Memory under pressure")
    #expect(alert.body == "")
  }
}
