import CoreGraphics

public enum CardFan {
  public static func frames(
    panelFrame: CGRect, cardSizes: [CGSize], screenMinX: CGFloat
  ) -> [CGRect] {
    var x = panelFrame.minX
    return cardSizes.map { size in
      x -= size.width / 2
      return CGRect(
        origin: CGPoint(x: max(x, screenMinX), y: panelFrame.maxY - size.height), size: size)
    }
  }
}
