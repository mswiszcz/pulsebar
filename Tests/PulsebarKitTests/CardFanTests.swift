import CoreGraphics
import PulsebarKit
import Testing

struct CardFanTests {
  private let panel = CGRect(x: 1000, y: 200, width: 425, height: 600)
  private let size = CGSize(width: 300, height: 250)

  @Test func firstCardShowsItsLeftHalfBesidePanel() {
    let frames = CardFan.frames(panelFrame: panel, cardSizes: [size], screenMinX: 0)
    #expect(frames == [CGRect(x: 850, y: 550, width: 300, height: 250)])
  }

  @Test func eachCardShiftsAnotherHalfWidthLeft() {
    let frames = CardFan.frames(panelFrame: panel, cardSizes: [size, size, size], screenMinX: 0)
    #expect(frames.map(\.minX) == [850, 700, 550])
  }

  @Test func topEdgesAlignWithPanel() {
    let tall = CGSize(width: 300, height: 400)
    let frames = CardFan.frames(panelFrame: panel, cardSizes: [size, tall], screenMinX: 0)
    #expect(frames.map(\.maxY) == [800, 800])
  }

  @Test func clampsAtScreenEdge() {
    let frames = CardFan.frames(panelFrame: panel, cardSizes: [size, size], screenMinX: 800)
    #expect(frames.map(\.minX) == [850, 800])
  }

  @Test func withoutCardsReturnsNothing() {
    #expect(CardFan.frames(panelFrame: panel, cardSizes: [], screenMinX: 0).isEmpty)
  }
}
