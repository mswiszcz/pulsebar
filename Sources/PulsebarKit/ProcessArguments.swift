public enum ProcessArguments {
  public static func executablePath(fromProcArgs bytes: some Collection<UInt8>) -> String? {
    let path = bytes.dropFirst(MemoryLayout<Int32>.size)
    guard let end = path.firstIndex(of: 0), end != path.startIndex else { return nil }
    return String(decoding: path[..<end], as: UTF8.self)
  }
}
