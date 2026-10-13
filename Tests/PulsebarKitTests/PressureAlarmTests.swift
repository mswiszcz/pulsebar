import PulsebarKit
import Testing

struct PressureAlarmTests {
  private func run(
    _ samples: [(PressureLevel, Double)], minimum: PressureLevel = .warning
  ) -> [PressureLevel] {
    var alarm = PressureAlarm()
    return samples.compactMap { alarm.update(level: $0.0, at: $0.1, minimum: minimum) }
  }

  @Test func briefSpikeDoesNotNotify() {
    #expect(
      run([(.warning, 0), (.warning, 8), (.normal, 9.9), (.warning, 12), (.normal, 20)]).isEmpty)
  }

  @Test func sustainedWarningNotifiesOnce() {
    #expect(run([(.warning, 0), (.warning, 10), (.warning, 20), (.warning, 60)]) == [.warning])
  }

  @Test func escalationToCriticalNotifiesAgain() {
    #expect(
      run([(.warning, 0), (.warning, 10), (.critical, 12), (.critical, 22), (.critical, 40)])
        == [.warning, .critical])
  }

  @Test func criticalFromNormalNotifiesCriticalAfterSustain() {
    #expect(run([(.critical, 0), (.critical, 5), (.critical, 10)]) == [.critical])
  }

  @Test func elevatedMixNotifiesWarningWhenCriticalIsBrief() {
    #expect(run([(.warning, 0), (.critical, 5), (.critical, 10)]) == [.warning])
  }

  @Test func flappingWithoutLongNormalDoesNotRenotify() {
    #expect(
      run([(.warning, 0), (.warning, 10), (.normal, 20), (.warning, 50), (.warning, 70)])
        == [.warning])
  }

  @Test func sixtySecondsNormalRearms() {
    #expect(
      run([
        (.warning, 0), (.warning, 10), (.normal, 20), (.normal, 80), (.warning, 81), (.warning, 91),
      ])
        == [.warning, .warning])
  }

  @Test func criticalOnlySettingSkipsWarning() {
    #expect(
      run([(.warning, 0), (.warning, 30), (.critical, 31), (.critical, 41)], minimum: .critical)
        == [.critical])
  }

  @Test func normalNeverNotifies() {
    #expect(run([(.normal, 0), (.normal, 100)]).isEmpty)
  }
}
