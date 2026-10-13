import Foundation

public struct ServerConfig: Codable, Equatable, Identifiable, Sendable {
  public var id: UUID
  public var name: String
  public var url: URL

  public init(id: UUID = UUID(), name: String, url: URL) {
    self.id = id
    self.name = name
    self.url = url
  }
}

public enum ServerURL {
  private static let defaultPort = 9100
  private static let defaultPath = "/metrics"
  private static let collectors = [
    "cpu", "meminfo", "loadavg", "stat", "time", "filesystem", "netdev", "drm",
  ]

  public static func normalize(_ input: String) -> URL? {
    let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
    let hasScheme = text.contains("://")
    guard var components = URLComponents(string: hasScheme ? text : "http://" + text),
      let scheme = components.scheme, ["http", "https"].contains(scheme),
      let host = components.host, !host.isEmpty
    else { return nil }
    if !hasScheme {
      components.port = components.port ?? defaultPort
      if components.path.isEmpty { components.path = defaultPath }
    }
    return components.url
  }

  public static func metricsRequest(_ url: URL, includeGPU: Bool = true) -> URL {
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      return url
    }
    components.queryItems =
      (components.queryItems ?? [])
      + collectors.filter { includeGPU || $0 != "drm" }.map {
        URLQueryItem(name: "collect[]", value: $0)
      }
    return components.url ?? url
  }
}
