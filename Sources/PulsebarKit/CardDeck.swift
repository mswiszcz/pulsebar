import CoreGraphics

public enum CardDeck {
  public static let stripHeight: CGFloat = 30
  public static let tuck: CGFloat = 6
  public static let hiddenMargin: CGFloat = 10
  public static let cornerRadius: CGFloat = 10

  public static func windowFrame(panelFrame: CGRect, height: CGFloat) -> CGRect {
    CGRect(
      x: panelFrame.minX, y: panelFrame.minY + hiddenMargin - height,
      width: panelFrame.width, height: height)
  }

  public static func maxHeight(panelFrame: CGRect, screenMinY: CGFloat) -> CGFloat {
    panelFrame.minY + hiddenMargin - screenMinY
  }
}
