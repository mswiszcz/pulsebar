import AppKit
import PulsebarKit
import SwiftUI

struct MenuBarLabel: View {
  let stats: Stats?

  var body: some View {
    Image(
      nsImage: MenuBarImage.make(
        pressure: stats?.memory?.pressure,
        readings: [
          MenuBarReading(
            name: "Memory", symbol: "memorychip",
            value: Format.wholePercent(stats?.memory?.usedFraction)),
          MenuBarReading(
            name: "CPU", symbol: "cpu", value: Format.wholePercent(stats?.cpuFraction)),
        ]))
  }
}

struct MenuBarReading: Sendable {
  let name: String
  let symbol: String
  let value: String
}

enum MenuBarImage {
  private static let height: CGFloat = 16
  private static let dotSize: CGFloat = 8
  private static let symbolGap: CGFloat = 3
  private static let readingGap: CGFloat = 8
  private static let widestValue = "100%"

  static func make(pressure: PressureLevel?, readings: [MenuBarReading]) -> NSImage {
    let slot = readings.map { reading in
      glyph(reading.symbol, color: .black).size.width + symbolGap + measure(widestValue)
    }
    let width = dotSize + readingGap + slot.reduce(0, +) + readingGap * CGFloat(readings.count - 1)
    let dotColor = pressure?.nsColor ?? .tertiaryLabelColor
    let image = NSImage(size: NSSize(width: ceil(width), height: height), flipped: false) { _ in
      let ink = NSColor.labelColor
      dotColor.setFill()
      NSBezierPath(ovalIn: NSRect(x: 0, y: (height - dotSize) / 2, width: dotSize, height: dotSize))
        .fill()
      var slotStart = dotSize + readingGap
      for (reading, slotWidth) in zip(readings, slot) {
        let symbol = glyph(reading.symbol, color: ink)
        let text = NSAttributedString(string: reading.value, attributes: attributes(ink))
        let contentWidth = symbol.size.width + symbolGap + text.size().width
        let x = slotStart + slotWidth - contentWidth
        symbol.draw(
          in: NSRect(
            x: x, y: (height - symbol.size.height) / 2, width: symbol.size.width,
            height: symbol.size.height))
        text.draw(
          at: NSPoint(x: x + symbol.size.width + symbolGap, y: (height - text.size().height) / 2))
        slotStart += slotWidth + readingGap
      }
      return true
    }
    image.isTemplate = false
    image.accessibilityDescription = readings.map { "\($0.name) \($0.value)" }.joined(
      separator: ", ")
    return image
  }

  private static func font() -> NSFont {
    .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
  }

  private static func attributes(_ color: NSColor) -> [NSAttributedString.Key: Any] {
    [.font: font(), .foregroundColor: color]
  }

  private static func measure(_ text: String) -> CGFloat {
    NSAttributedString(string: text, attributes: attributes(.black)).size().width
  }

  private static func glyph(_ name: String, color: NSColor) -> NSImage {
    let configuration = NSImage.SymbolConfiguration(
      pointSize: NSFont.systemFontSize - 1, weight: .regular
    )
    .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
    return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
      .withSymbolConfiguration(configuration) ?? NSImage()
  }
}
