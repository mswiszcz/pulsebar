import PulsebarKit
import Testing

struct ServerURLTests {
  @Test(arguments: [
    ("nas.lan", "http://nas.lan:9100/metrics"),
    ("nas.lan:9200", "http://nas.lan:9200/metrics"),
    ("192.168.1.5", "http://192.168.1.5:9100/metrics"),
    ("  nas.lan  ", "http://nas.lan:9100/metrics"),
    ("http://nas.lan:9100/metrics", "http://nas.lan:9100/metrics"),
    ("https://x.lan/node/metrics?foo=1", "https://x.lan/node/metrics?foo=1"),
    ("http://nas.lan", "http://nas.lan"),
  ])
  func normalizesInput(input: String, expected: String) {
    #expect(ServerURL.normalize(input)?.absoluteString == expected)
  }

  @Test(arguments: ["ftp://x", "", "   ", "http://", "not a host!", "nas lan"])
  func rejectsInvalidInput(input: String) {
    #expect(ServerURL.normalize(input) == nil)
  }

  @Test func metricsRequestAppendsAllCollectors() throws {
    let url = try #require(ServerURL.normalize("nas.lan"))
    #expect(
      ServerURL.metricsRequest(url).absoluteString
        == "http://nas.lan:9100/metrics?collect%5B%5D=cpu&collect%5B%5D=meminfo"
        + "&collect%5B%5D=loadavg&collect%5B%5D=stat&collect%5B%5D=time"
        + "&collect%5B%5D=filesystem&collect%5B%5D=netdev&collect%5B%5D=drm")
  }

  @Test func metricsRequestOmitsDRMWithoutGPU() throws {
    let url = try #require(ServerURL.normalize("nas.lan"))
    #expect(
      ServerURL.metricsRequest(url, includeGPU: false).absoluteString
        == "http://nas.lan:9100/metrics?collect%5B%5D=cpu&collect%5B%5D=meminfo"
        + "&collect%5B%5D=loadavg&collect%5B%5D=stat&collect%5B%5D=time"
        + "&collect%5B%5D=filesystem&collect%5B%5D=netdev")
  }

  @Test func metricsRequestAppendsAfterExistingQuery() throws {
    let url = try #require(ServerURL.normalize("https://x.lan/node/metrics?foo=1"))
    #expect(
      ServerURL.metricsRequest(url).absoluteString.hasPrefix(
        "https://x.lan/node/metrics?foo=1&collect%5B%5D=cpu&"))
  }
}
