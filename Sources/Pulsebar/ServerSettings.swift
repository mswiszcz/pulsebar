import Foundation
import PulsebarKit

enum ServerSettings {
  static let key = "servers"

  static func load(from defaults: UserDefaults = .standard) -> [ServerConfig] {
    guard let data = defaults.data(forKey: key) else { return [] }
    return (try? JSONDecoder().decode([ServerConfig].self, from: data)) ?? []
  }

  static func save(_ servers: [ServerConfig], to defaults: UserDefaults = .standard) {
    guard let data = try? JSONEncoder().encode(servers) else { return }
    defaults.set(data, forKey: key)
  }
}
