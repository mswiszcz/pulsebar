import Observation
import PulsebarKit

@MainActor
@Observable
final class StatsStore {
  private(set) var stats: Stats?
  private(set) var history = RingBuffer<HistorySample>(capacity: TimelineAxis.capacity)
  private let collector = StatsCollector()

  init() {
    Task { await run() }
  }

  private func run() async {
    while !Task.isCancelled {
      let sample = await collector.sample()
      stats = sample
      history.append(HistorySample(sample))
      try? await Task.sleep(for: .seconds(2))
    }
  }
}
