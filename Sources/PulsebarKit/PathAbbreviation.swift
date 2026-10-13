public enum PathAbbreviation {
  public static func short(_ path: String, home: String) -> String {
    let homeRelative: Substring? =
      path == home ? "" : path.hasPrefix(home + "/") ? path.dropFirst(home.count + 1) : nil
    let root = homeRelative == nil ? "/" : "~/"
    let components = (homeRelative ?? Substring(path)).split(separator: "/")
    guard !components.isEmpty else { return homeRelative == nil ? "/" : "~" }
    let tail = components.suffix(2).joined(separator: "/")
    return components.count > 2 ? root + "…/" + tail : root + tail
  }
}
