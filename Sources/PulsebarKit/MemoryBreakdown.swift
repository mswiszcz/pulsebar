public struct MemoryBreakdown: Equatable, Sendable {
  public let app: UInt64
  public let wired: UInt64
  public let compressed: UInt64
  public let cachedFiles: UInt64

  public var used: UInt64 { app + wired + compressed }

  public init(
    pageSize: UInt64, internalPages: UInt64, purgeablePages: UInt64, externalPages: UInt64,
    wiredPages: UInt64, compressorPages: UInt64
  ) {
    app = (internalPages - min(purgeablePages, internalPages)) * pageSize
    wired = wiredPages * pageSize
    compressed = compressorPages * pageSize
    cachedFiles = (externalPages + purgeablePages) * pageSize
  }
}
