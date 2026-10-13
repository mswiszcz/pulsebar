public struct MetricSample: Equatable, Sendable {
  public let name: String
  public let labels: [String: String]
  public let value: Double

  public init(name: String, labels: [String: String] = [:], value: Double) {
    self.name = name
    self.labels = labels
    self.value = value
  }
}

public enum PrometheusText {
  public static func parse(_ bytes: [UInt8]) -> [MetricSample] {
    String(decoding: bytes, as: UTF8.self)
      .split(whereSeparator: \.isNewline)
      .compactMap(parseLine)
  }

  private static func parseLine(_ line: Substring) -> MetricSample? {
    let trimmed = line.drop { $0.isWhitespace }
    guard let first = trimmed.first, first != "#" else { return nil }
    let name = trimmed.prefix { $0 != "{" && !$0.isWhitespace }
    guard !name.isEmpty else { return nil }
    var rest = trimmed.dropFirst(name.count)
    var labels: [String: String] = [:]
    if rest.first == "{" {
      guard let parsed = parseLabels(rest.dropFirst()) else { return nil }
      labels = parsed.labels
      rest = parsed.rest
    }
    let fields = rest.split(whereSeparator: \.isWhitespace)
    guard fields.count == 1 || fields.count == 2, let value = Double(fields[0]) else { return nil }
    if fields.count == 2, Int64(fields[1]) == nil { return nil }
    return MetricSample(name: String(name), labels: labels, value: value)
  }

  private static func parseLabels(_ input: Substring) -> (
    labels: [String: String], rest: Substring
  )? {
    var labels: [String: String] = [:]
    var cursor = input.drop { $0.isWhitespace }
    while cursor.first != "}" {
      let key = cursor.prefix { $0.isLetter || $0.isNumber || $0 == "_" }
      guard !key.isEmpty else { return nil }
      cursor = cursor.dropFirst(key.count).drop { $0.isWhitespace }
      guard cursor.first == "=" else { return nil }
      cursor = cursor.dropFirst().drop { $0.isWhitespace }
      guard cursor.first == "\"", let quoted = parseQuoted(cursor.dropFirst()) else { return nil }
      labels[String(key)] = quoted.value
      cursor = quoted.rest.drop { $0.isWhitespace }
      guard cursor.first == "," || cursor.first == "}" else { return nil }
      if cursor.first == "," { cursor = cursor.dropFirst().drop { $0.isWhitespace } }
    }
    return (labels, cursor.dropFirst())
  }

  private static func parseQuoted(_ input: Substring) -> (value: String, rest: Substring)? {
    var value = ""
    var escaping = false
    var index = input.startIndex
    while index < input.endIndex {
      let character = input[index]
      index = input.index(after: index)
      if escaping {
        value.append(character == "n" ? "\n" : character)
        escaping = false
      } else if character == "\\" {
        escaping = true
      } else if character == "\"" {
        return (value, input[index...])
      } else {
        value.append(character)
      }
    }
    return nil
  }
}
