import PulsebarKit
import Testing

struct CounterRateTests {
  @Test func withoutPreviousSampleIsNil() {
    #expect(CounterRate.perSecond(previous: nil, current: 500, interval: 2) == nil)
  }

  @Test func withNormalDeltaIsBytesPerSecond() {
    #expect(CounterRate.perSecond(previous: 1_000, current: 5_000, interval: 2) == 2_000)
  }

  @Test func withUnchangedCounterIsZero() {
    #expect(CounterRate.perSecond(previous: 42, current: 42, interval: 2) == 0)
  }

  @Test func whenCounterDecreasesIsNil() {
    #expect(CounterRate.perSecond(previous: 5_000, current: 10, interval: 2) == nil)
  }

  @Test(arguments: [0.0, -1.0])
  func withNonPositiveIntervalIsNil(interval: Double) {
    #expect(CounterRate.perSecond(previous: 1, current: 9, interval: interval) == nil)
  }
}

struct RateMeterTests {
  @Test func firstUpdateIsNil() {
    var meter = RateMeter()
    #expect(meter.update(value: 100, at: 10) == nil)
  }

  @Test func laterUpdatesUseLastSample() {
    var meter = RateMeter()
    _ = meter.update(value: 100, at: 10)
    #expect(meter.update(value: 300, at: 12) == 100)
    #expect(meter.update(value: 900, at: 14) == 300)
  }

  @Test func whenCounterResetsRecoversNextTick() {
    var meter = RateMeter()
    _ = meter.update(value: 1_000, at: 10)
    #expect(meter.update(value: 50, at: 12) == nil)
    #expect(meter.update(value: 250, at: 14) == 100)
  }

  @Test func withSameTimestampIsNil() {
    var meter = RateMeter()
    _ = meter.update(value: 100, at: 10)
    #expect(meter.update(value: 200, at: 10) == nil)
  }
}
