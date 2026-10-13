public enum ProcessArguments {
  public static func executablePath(fromProcArgs bytes: some Collection<UInt8>) -> String? {
    let path = bytes.dropFirst(MemoryLayout<Int32>.size)
    guard let end = path.firstIndex(of: 0), end != path.startIndex else { return nil }
    return String(decoding: path[..<end], as: UTF8.self)
  }

  public static func arguments(fromProcArgs bytes: some Collection<UInt8>) -> [String] {
    let countSize = MemoryLayout<Int32>.size
    guard bytes.count > countSize else { return [] }
    let count = bytes.prefix(countSize).reversed().reduce(0) { $0 << 8 | Int($1) }
    let afterCount = bytes.dropFirst(countSize)
    guard let pathEnd = afterCount.firstIndex(of: 0),
      let firstArgument = afterCount[pathEnd...].firstIndex(where: { $0 != 0 })
    else { return [] }
    return afterCount[firstArgument...]
      .split(separator: 0, maxSplits: count, omittingEmptySubsequences: false)
      .prefix(count)
      .map { String(decoding: $0, as: UTF8.self) }
  }
}
