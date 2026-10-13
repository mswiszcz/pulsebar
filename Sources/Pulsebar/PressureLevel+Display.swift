import AppKit
import PulsebarKit
import SwiftUI

extension PressureLevel {
  var verdict: String {
    switch self {
    case .normal: "Memory: normal"
    case .warning: "Memory: under pressure"
    case .critical: "Memory: critical"
    }
  }

  var nsColor: NSColor {
    switch self {
    case .normal: .systemGreen
    case .warning: .systemYellow
    case .critical: .systemRed
    }
  }

  var color: Color { Color(nsColor: nsColor) }
}
