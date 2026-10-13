import Foundation
import PulsebarKit

enum ServerSettings {
  static let key = "servers"

  static func load(from defaults: UserDefaults = .standard) -> [ServerConfig] {
    guard let data = defaults.data(forKey: key) else { return [] }
    return (try? JSONDecoder().decode([ServerConfig].self, from: data)) ?? []
  }
}

enum ServerTestResult {
  static func reason(_ reason: FailureReason, url: URL) -> String {
    String(describing: reason)
  }
}
