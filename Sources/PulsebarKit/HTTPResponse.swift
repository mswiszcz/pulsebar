import Foundation

public struct HTTPResponse: Sendable {
  public let status: Int
  public let body: [UInt8]

  public init?(_ bytes: [UInt8]) {
    let data = Data(bytes)
    guard let headerEnd = data.range(of: Data("\r\n\r\n".utf8)) else { return nil }
    let statusLine = String(decoding: data[..<headerEnd.lowerBound], as: UTF8.self)
      .prefix { $0 != "\r" }
    let statusParts = statusLine.split(separator: " ")
    guard statusParts.count >= 2, statusParts[0].hasPrefix("HTTP/"),
      let status = Int(statusParts[1])
    else { return nil }
    self.status = status
    body = Array(data[headerEnd.upperBound...])
  }
}
