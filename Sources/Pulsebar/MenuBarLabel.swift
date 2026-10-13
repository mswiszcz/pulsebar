import AppKit
import PulsebarKit
import SwiftUI

struct MenuBarLabel: View {
  let stats: Stats?
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Image(
      nsImage: MenuBarImage.make(
        colorScheme: colorScheme,
        readings: [
          MenuBarReading(
            name: "Memory", symbol: "memorychip",
            value: Format.wholePercent(stats?.memory?.usedFraction),
            pressure: stats?.memory?.pressure),
          MenuBarReading(
            name: "CPU", symbol: "cpu", value: Format.wholePercent(stats?.cpuFraction)),
        ]))
  }
}

struct MenuBarReading: Equatable, Sendable {
  let name: String
  let symbol: String
  let value: String
  var pressure: PressureLevel?
}

@MainActor
enum MenuBarImage {
  private static let height: CGFloat = 16
  private static let symbolGap: CGFloat = 3
  private static let readingGap: CGFloat = 8
  private static let widestValue = "100%"

  private static var last: (colorScheme: ColorScheme, readings: [MenuBarReading], image: NSImage)?
  private static var slotWidths: [String: CGFloat] = [:]

  static func make(colorScheme: ColorScheme, readings: [MenuBarReading]) -> NSImage {
    if let last, (last.colorScheme, last.readings) == (colorScheme, readings) {
      return last.image
    }
    let image = draw(readings: readings)
    last = (colorScheme, readings, image)
    return image
  }

  private static func slotWidth(_ symbol: String) -> CGFloat {
    if let width = slotWidths[symbol] { return width }
    let width = glyph(symbol, color: .black).size.width + symbolGap + measure(widestValue)
    slotWidths[symbol] = width
    return width
  }

  private static func draw(readings: [MenuBarReading]) -> NSImage {
    let slot = readings.map { slotWidth($0.symbol) }
    let width = slot.reduce(0, +) + readingGap * CGFloat(readings.count - 1)
    let image = NSImage(size: NSSize(width: ceil(width), height: height), flipped: false) { _ in
      let ink = NSColor.labelColor
      var slotStart: CGFloat = 0
      for (reading, slotWidth) in zip(readings, slot) {
        let symbol = glyph(reading.symbol, color: reading.pressure?.nsColor ?? ink)
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
