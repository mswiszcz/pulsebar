import Darwin

struct NetworkSampler {
  private var downMeter = RateMeter()
  private var upMeter = RateMeter()

  mutating func sample(at time: Double) -> NetworkStats {
    let totals = Self.interfaceTotals()
    return NetworkStats(
      downRate: totals.flatMap { downMeter.update(value: $0.received, at: time) },
      upRate: totals.flatMap { upMeter.update(value: $0.sent, at: time) }
    )
  }

  private static func interfaceTotals() -> (received: UInt64, sent: UInt64)? {
    var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
    var size = 0
    guard sysctl(&mib, UInt32(mib.count), nil, &size, nil, 0) == 0 else { return nil }
    var buffer = [UInt8](repeating: 0, count: size)
    guard sysctl(&mib, UInt32(mib.count), &buffer, &size, nil, 0) == 0 else { return nil }

    return buffer.withUnsafeBytes { raw in
      var received: UInt64 = 0
      var sent: UInt64 = 0
      var offset = 0
      while offset + MemoryLayout<if_msghdr>.size <= size {
        let header = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr.self)
        guard header.ifm_msglen > 0 else { break }
        if header.ifm_type == RTM_IFINFO2, header.ifm_flags & IFF_LOOPBACK == 0,
          offset + MemoryLayout<if_msghdr2>.size <= size
        {
          let message = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
          received += message.ifm_data.ifi_ibytes
          sent += message.ifm_data.ifi_obytes
        }
        offset += Int(header.ifm_msglen)
      }
      return (received, sent)
    }
  }
}
