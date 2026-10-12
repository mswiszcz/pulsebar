import Observation
import PulsebarKit

@MainActor
@Observable
final class StatsStore {
  private(set) var stats: Stats?
  private let collector = StatsCollector()

  init() {
    Task { await run() }
  }

  private func run() async {
    while !Task.isCancelled {
      stats = await collector.sample()
      try? await Task.sleep(for: .seconds(2))
    }
  }
}
