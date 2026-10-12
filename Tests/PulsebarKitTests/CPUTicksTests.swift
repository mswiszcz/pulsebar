import PulsebarKit
import Testing

struct CPUTicksTests {
  private let before = CPUTicks(user: 100, system: 50, idle: 800, nice: 50)

  @Test func busyFractionIsUserPlusSystemOverAllTicks() {
    let after = CPUTicks(user: 160, system: 70, idle: 900, nice: 70)
    #expect(after.busyFraction(since: before) == 0.4)
  }

  @Test func withoutElapsedTicksIsNil() {
    #expect(before.busyFraction(since: before) == nil)
  }

  @Test func whenAnyCounterDecreasesIsNil() {
    let after = CPUTicks(user: 90, system: 70, idle: 900, nice: 50)
    #expect(after.busyFraction(since: before) == nil)
  }
}
