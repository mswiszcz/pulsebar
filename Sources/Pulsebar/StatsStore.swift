import Foundation
import Observation
import PulsebarKit

@MainActor
@Observable
final class StatsStore {
  private static let sampleInterval: Duration = .seconds(2)
  private static let snapshotInterval = 30.0
  private static let dockerInterval = 15.0
  private static let growthThreshold: UInt64 = 500 * 1_048_576

  private(set) var panel = PanelModel()
  var expandedApp: AppIdentity?
  var isPopoverOpen = false {
    didSet {
      if isPopoverOpen, !oldValue { Task { await refreshDetails() } }
    }
  }

  @ObservationIgnored private let collector = StatsCollector()
  @ObservationIgnored private let dockerMonitor = DockerMonitor()
  @ObservationIgnored private let notifier = PressureNotifier()
  @ObservationIgnored private var snapshots = RingBuffer<[AppIdentity: UInt64]>(capacity: 20)
  @ObservationIgnored private var lastSnapshot: Double?
  @ObservationIgnored private var lastDockerPoll: Double?
  @ObservationIgnored private var alarm = PressureAlarm()

  var stats: Stats? { panel.stats }

  init() {
    notifier.onOpen = { [weak self] in
      if self?.isPopoverOpen == false { MenuBarPanel.open() }
    }
    Task { await run() }
    Task { await pollDocker() }
    Task { if AlertSettings.isEnabled { await notifier.requestAuthorizationIfNeeded() } }
  }

  func requestNotificationAuthorization() {
    Task { await notifier.requestAuthorizationIfNeeded() }
  }

  private func run() async {
    while !Task.isCancelled {
      let sample = await collector.sample(includeDetails: isPopoverOpen)
      let now = ProcessInfo.processInfo.systemUptime
      panel.stats = sample
      panel.history.append(HistorySample(sample))
      recordSnapshot(sample, at: now)
      checkPressure(sample, at: now)
      try? await Task.sleep(for: Self.sampleInterval)
    }
  }

  private func refreshDetails() async {
    let sample = await collector.sample(includeDetails: true)
    panel.stats = sample
  }

  private func recordSnapshot(_ sample: Stats, at time: Double) {
    guard lastSnapshot.map({ time - $0 >= Self.snapshotInterval }) ?? true else { return }
    lastSnapshot = time
    snapshots.append(sample.processes.largeApps)
    let window = snapshots.elements
    panel.growth = MemoryGrowth.growth(snapshots: window, threshold: Self.growthThreshold)
    panel.growthMinutes = Int(
      (Double(window.count - 1) * Self.snapshotInterval / 60).rounded(.up))
  }

  private func checkPressure(_ sample: Stats, at time: Double) {
    guard let level = sample.memory?.pressure,
      let notify = alarm.update(level: level, at: time, minimum: AlertSettings.threshold.level),
      AlertSettings.isEnabled
    else { return }
    notifier.post(
      PressureAlert(
        level: notify, growth: panel.growth, growthMinutes: panel.growthMinutes,
        apps: sample.apps, formatBytes: Format.memory))
  }

  private func pollDocker() async {
    while !Task.isCancelled {
      let now = ProcessInfo.processInfo.systemUptime
      let wanted = isPopoverOpen || panel.stats?.apps.contains { $0.app.isDocker } == true
      if wanted, lastDockerPoll.map({ now - $0 >= Self.dockerInterval }) ?? true {
        lastDockerPoll = now
        panel.docker = await dockerMonitor.sample()
      }
      try? await Task.sleep(for: .seconds(1))
    }
  }
}
