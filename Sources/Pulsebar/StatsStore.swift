import Foundation
import Observation
import PulsebarKit

@MainActor
@Observable
final class StatsStore {
  private static let sampleInterval: Duration = .seconds(2)
  private static let sampleTolerance: Duration = .milliseconds(250)
  private static let snapshotInterval = 30.0
  private static let dockerInterval = 15.0
  private static let growthThreshold: UInt64 = 500 * 1_048_576

  private(set) var panel = PanelModel()
  var expandedApp: AppIdentity?
  var expandedServer: UUID?
  var isPopoverOpen = false {
    didSet {
      guard isPopoverOpen, !oldValue else { return }
      Task { await refreshDetails() }
      Task { await refreshDockerIfStale() }
      if !configuredServers.isEmpty {
        Task { await refreshStaleHomelab() }
      }
    }
  }

  @ObservationIgnored private let collector = StatsCollector()
  @ObservationIgnored private let dockerMonitor = DockerMonitor()
  @ObservationIgnored private let homelab = HomelabMonitor()
  @ObservationIgnored private let notifier = PressureNotifier()
  @ObservationIgnored private var snapshots = RingBuffer<[AppIdentity: UInt64]>(capacity: 20)
  @ObservationIgnored private var lastSnapshot: Double?
  @ObservationIgnored private var lastDockerPoll: Double?
  @ObservationIgnored private var alarm = PressureAlarm()
  @ObservationIgnored private var homelabTask: Task<Void, Never>?
  @ObservationIgnored private var configuredServers: [ServerConfig] = []

  var stats: Stats? { panel.stats }

  init() {
    notifier.onOpen = { [weak self] in
      if self?.isPopoverOpen == false { MenuBarPanel.open() }
    }
    Task { await run() }
    Task { await pollDocker() }
    startHomelab()
    NotificationCenter.default.addObserver(
      forName: UserDefaults.didChangeNotification, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.restartHomelabIfChanged() }
    }
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
      try? await Task.sleep(for: Self.sampleInterval, tolerance: Self.sampleTolerance)
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
      if isPopoverOpen || panel.stats?.apps.contains(where: { $0.app.isDocker }) == true {
        await refreshDockerIfStale()
      }
      try? await Task.sleep(for: .seconds(nextDockerPoll), tolerance: .seconds(1))
    }
  }

  private var nextDockerPoll: Double {
    guard let lastDockerPoll else { return Self.dockerInterval }
    let elapsed = ProcessInfo.processInfo.systemUptime - lastDockerPoll
    return elapsed < Self.dockerInterval ? Self.dockerInterval - elapsed : Self.dockerInterval
  }

  private func refreshDockerIfStale() async {
    let now = ProcessInfo.processInfo.systemUptime
    guard lastDockerPoll.map({ now - $0 >= Self.dockerInterval }) ?? true else { return }
    lastDockerPoll = now
    panel.docker = await dockerMonitor.sample()
  }

  private func refreshStaleHomelab() async {
    panel.servers = await homelab.poll(at: Date().timeIntervalSince1970, staleOnly: true)
  }

  private func startHomelab() {
    homelabTask?.cancel()
    let servers = ServerSettings.load()
    configuredServers = servers
    homelabTask = Task { await runHomelab(servers) }
  }

  private func restartHomelabIfChanged() {
    guard ServerSettings.load() != configuredServers else { return }
    startHomelab()
  }

  private func runHomelab(_ servers: [ServerConfig]) async {
    await homelab.configure(servers)
    guard !servers.isEmpty else {
      panel.servers = []
      return
    }
    while !Task.isCancelled {
      panel.servers = await homelab.poll(at: Date().timeIntervalSince1970, staleOnly: false)
      let delay = await homelab.secondsUntilNextPoll(at: Date().timeIntervalSince1970)
      try? await Task.sleep(for: .seconds(delay), tolerance: .seconds(1))
    }
  }
}
