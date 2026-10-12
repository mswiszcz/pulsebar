public enum AppGrouping {
  public static func appName(forExecutablePath path: String) -> String? {
    let components = path.split(separator: "/")
    guard let executable = components.last else { return nil }
    let bundle = components.dropLast().first { $0.hasSuffix(".app") && $0.count > ".app".count }
    return String(bundle?.dropLast(".app".count) ?? executable)
  }
}
