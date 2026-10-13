import PulsebarKit
import Testing

struct PollBackoffTests {
  private func failing(_ count: Int, at time: Double) -> PollBackoff {
    var backoff = PollBackoff()
    for _ in 0..<count { backoff.record(success: false, at: time) }
    return backoff
  }

  @Test func neverPolledIsDue() {
    #expect(PollBackoff().isDue(at: 0))
  }

  @Test func dueAfterTenSecondsOnly() {
    var backoff = PollBackoff()
    backoff.record(success: true, at: 0)
    #expect(!backoff.isDue(at: 9))
    #expect(backoff.isDue(at: 10))
  }

  @Test func twoFailuresKeepTenSeconds() {
    let backoff = failing(2, at: 0)
    #expect(backoff.currentInterval == 10)
    #expect(backoff.isDue(at: 10))
  }

  @Test func threeFailuresBackOffToSixtySeconds() {
    let backoff = failing(3, at: 0)
    #expect(backoff.currentInterval == 60)
    #expect(!backoff.isDue(at: 59))
    #expect(backoff.isDue(at: 60))
  }

  @Test func successAfterBackoffRestoresTenSeconds() {
    var backoff = failing(3, at: 0)
    backoff.record(success: true, at: 60)
    #expect(backoff.consecutiveFailures == 0)
    #expect(backoff.currentInterval == 10)
    #expect(backoff.isDue(at: 70))
  }

  @Test func staleUsesTenSecondsDuringBackoff() {
    var backoff = failing(3, at: 0)
    #expect(backoff.isStale(at: 9) == false)
    #expect(backoff.isStale(at: 10))
    backoff.record(success: true, at: 10)
    #expect(!backoff.isStale(at: 15))
  }

  @Test func neverPolledIsStale() {
    #expect(PollBackoff().isStale(at: 0))
  }
}
