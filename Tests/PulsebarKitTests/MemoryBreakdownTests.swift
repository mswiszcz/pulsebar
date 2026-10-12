import PulsebarKit
import Testing

struct MemoryBreakdownTests {
  private func breakdown(
    internalPages: UInt64 = 1_000, purgeablePages: UInt64 = 100, externalPages: UInt64 = 400,
    wiredPages: UInt64 = 200, compressorPages: UInt64 = 50
  ) -> MemoryBreakdown {
    MemoryBreakdown(
      pageSize: 16_384, internalPages: internalPages, purgeablePages: purgeablePages,
      externalPages: externalPages, wiredPages: wiredPages, compressorPages: compressorPages)
  }

  @Test func appMemoryExcludesPurgeable() {
    #expect(breakdown().app == 900 * 16_384)
  }

  @Test func cachedFilesAreExternalPlusPurgeable() {
    #expect(breakdown().cachedFiles == 500 * 16_384)
  }

  @Test func usedIsAppWiredAndCompressed() {
    #expect(breakdown().used == (900 + 200 + 50) * 16_384)
  }

  @Test func withPurgeableAboveInternalAppIsZero() {
    #expect(breakdown(internalPages: 10, purgeablePages: 30).app == 0)
  }
}
