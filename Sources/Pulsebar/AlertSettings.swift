import Foundation
import PulsebarKit

enum AlertThreshold: String, CaseIterable, Identifiable {
  case warning
  case critical

  var id: String { rawValue }

  var title: String {
    switch self {
    case .warning: "Warning"
    case .critical: "Critical only"
    }
  }

  var level: PressureLevel {
    switch self {
    case .warning: .warning
    case .critical: .critical
    }
  }
}

enum AlertSettings {
  static let notifyKey = "notifyOnPressure"
  static let thresholdKey = "notifyThreshold"

  static func registerDefaults() {
    UserDefaults.standard.register(defaults: [
      notifyKey: true, thresholdKey: AlertThreshold.warning.rawValue,
    ])
  }

  static var isEnabled: Bool { UserDefaults.standard.bool(forKey: notifyKey) }

  static var threshold: AlertThreshold {
    UserDefaults.standard.string(forKey: thresholdKey).flatMap(AlertThreshold.init) ?? .warning
  }
}
