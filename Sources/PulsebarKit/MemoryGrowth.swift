public enum MemoryGrowth {
  public static func growth(
    snapshots: [[AppIdentity: UInt64]], threshold: UInt64
  ) -> [AppIdentity: UInt64] {
    guard let latest = snapshots.last else { return [:] }
    var grown: [AppIdentity: UInt64] = [:]
    for (app, current) in latest {
      guard let baseline = snapshots.lazy.compactMap({ $0[app] }).first,
        current > baseline, current - baseline >= threshold
      else { continue }
      grown[app] = current - baseline
    }
    return grown
  }

  public static func snapshot(_ apps: [AppUsage], minimum: UInt64) -> [AppIdentity: UInt64] {
    Dictionary(
      apps.filter { $0.memory >= minimum }.map { ($0.app, $0.memory) },
      uniquingKeysWith: +)
  }
}
