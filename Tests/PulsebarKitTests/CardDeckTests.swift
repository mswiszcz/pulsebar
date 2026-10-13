import CoreGraphics
import PulsebarKit
import Testing

struct CardDeckTests {
  private let panel = CGRect(x: 1000, y: 200, width: 425, height: 600)

  @Test func windowMatchesPanelWidth() {
    let frame = CardDeck.windowFrame(panelFrame: panel, height: 100)
    #expect(frame.minX == panel.minX)
    #expect(frame.width == panel.width)
    #expect(frame.height == 100)
  }

  @Test func windowTopSitsTenPointsAbovePanelBottom() {
    let frame = CardDeck.windowFrame(panelFrame: panel, height: 100)
    #expect(frame.maxY == panel.minY + CardDeck.hiddenMargin)
  }

  @Test func growingHeightKeepsTopFixed() {
    let short = CardDeck.windowFrame(panelFrame: panel, height: 100)
    let tall = CardDeck.windowFrame(panelFrame: panel, height: 300)
    #expect(short.maxY == tall.maxY)
  }

  @Test func maxHeightReachesScreenBottom() {
    #expect(CardDeck.maxHeight(panelFrame: panel, screenMinY: 50) == 160)
  }
}
