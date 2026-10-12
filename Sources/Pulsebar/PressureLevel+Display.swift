import AppKit
import PulsebarKit

extension PressureLevel {
  var title: String {
    switch self {
    case .normal: "Normal"
    case .warning: "Warning"
    case .critical: "Critical"
    }
  }

  var color: NSColor {
    switch self {
    case .normal: .systemGreen
    case .warning: .systemYellow
    case .critical: .systemRed
    }
  }

  var dot: NSImage {
    let color = color
    let image = NSImage(size: NSSize(width: 8, height: 8), flipped: false) { rect in
      color.setFill()
      NSBezierPath(ovalIn: rect).fill()
      return true
    }
    image.isTemplate = false
    return image
  }
}
