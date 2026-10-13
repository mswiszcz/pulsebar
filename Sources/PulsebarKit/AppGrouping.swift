public struct AppIdentity: Hashable, Sendable {
  public let name: String
  public let bundlePath: String?

  public init(name: String, bundlePath: String?) {
    self.name = name
    self.bundlePath = bundlePath
  }

  public var isDocker: Bool { bundlePath?.hasSuffix("/Docker.app") == true }
}

public enum AppGrouping {
  public static func identity(forExecutablePath path: String) -> AppIdentity? {
    let components = path.split(separator: "/")
    guard let executable = components.last else { return nil }
    guard
      let bundleIndex = components.dropLast().firstIndex(where: {
        $0.hasSuffix(".app") && $0.count > ".app".count
      })
    else { return AppIdentity(name: String(executable), bundlePath: nil) }
    let root = path.hasPrefix("/") ? "/" : ""
    return AppIdentity(
      name: String(components[bundleIndex].dropLast(".app".count)),
      bundlePath: root + components[...bundleIndex].joined(separator: "/")
    )
  }
}
