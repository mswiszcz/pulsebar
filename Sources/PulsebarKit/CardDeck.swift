import CoreGraphics

public enum CardDeck {
  public static let stripHeight: CGFloat = 30
  public static let cornerRadius: CGFloat = 10
  public static let sideInset: CGFloat = 8

  public static func cardWidth(panelWidth: CGFloat) -> CGFloat { panelWidth - 2 * sideInset }

  public static func collapsedFrames(panelFrame: CGRect, count: Int) -> [CGRect] {
    let size = CGSize(
      width: cardWidth(panelWidth: panelFrame.width), height: stripHeight + cornerRadius)
    return (0..<count).map { index in
      CGRect(
        origin: CGPoint(
          x: panelFrame.minX + sideInset,
          y: panelFrame.minY + cornerRadius - size.height - CGFloat(index) * stripHeight),
        size: size)
    }
  }

  public static func expandedFrame(collapsed: CGRect, height: CGFloat, screenMaxY: CGFloat)
    -> CGRect
  {
    let y = min(collapsed.minY, screenMaxY - height)
    return CGRect(x: collapsed.minX, y: y, width: collapsed.width, height: height)
  }
}
