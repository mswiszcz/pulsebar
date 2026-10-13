import CoreGraphics
import PulsebarKit
import Testing

struct CardDeckTests {
  private let panel = CGRect(x: 1000, y: 200, width: 425, height: 600)

  @Test func collapsedCardsAreCenteredUnderPanel() {
    let frames = CardDeck.collapsedFrames(panelFrame: panel, count: 2)
    #expect(frames.map(\.minX) == [1008, 1008])
    #expect(frames.map(\.width) == [409, 409])
    #expect(frames.map(\.height) == [40, 40])
  }

  @Test func firstCardTucksCornerRadiusBehindPanel() {
    let frame = CardDeck.collapsedFrames(panelFrame: panel, count: 1)[0]
    #expect(frame.maxY == panel.minY + CardDeck.cornerRadius)
    #expect(frame.minY == panel.minY - CardDeck.stripHeight)
  }

  @Test func eachCardSitsOneStripLowerAndTucksBehindPrevious() {
    let frames = CardDeck.collapsedFrames(panelFrame: panel, count: 3)
    #expect(frames.map(\.minY) == [170, 140, 110])
    #expect(frames[1].maxY == frames[0].minY + CardDeck.cornerRadius)
  }

  @Test func withoutServersReturnsNothing() {
    #expect(CardDeck.collapsedFrames(panelFrame: panel, count: 0).isEmpty)
  }

  @Test func expandedCardKeepsStripBottomAndGrowsUp() {
    let collapsed = CardDeck.collapsedFrames(panelFrame: panel, count: 2)[1]
    let frame = CardDeck.expandedFrame(collapsed: collapsed, height: 300, screenMaxY: 1000)
    #expect(frame.minY == collapsed.minY)
    #expect(frame.minX == collapsed.minX)
    #expect(frame.width == collapsed.width)
    #expect(frame.height == 300)
  }

  @Test func expandedCardClampsBelowScreenTop() {
    let collapsed = CardDeck.collapsedFrames(panelFrame: panel, count: 1)[0]
    let frame = CardDeck.expandedFrame(collapsed: collapsed, height: 300, screenMaxY: 400)
    #expect(frame.maxY == 400)
  }
}
