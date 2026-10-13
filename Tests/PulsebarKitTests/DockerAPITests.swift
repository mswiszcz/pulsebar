import PulsebarKit
import Testing

struct HTTPResponseTests {
  @Test func splitsStatusAndBodyAfterHeaders() throws {
    let raw = Array(
      "HTTP/1.0 200 OK\r\nContent-Type: application/json\r\nApi-Version: 1.56\r\n\r\n[{\"a\":1}]"
        .utf8)
    let response = try #require(HTTPResponse(raw))
    #expect(response.status == 200)
    #expect(response.body == Array("[{\"a\":1}]".utf8))
  }

  @Test func keepsErrorStatus() throws {
    let response = try #require(HTTPResponse(Array("HTTP/1.0 404 Not Found\r\n\r\n{}".utf8)))
    #expect(response.status == 404)
  }

  @Test(arguments: [
    "", "HTTP/1.0 200 OK\r\nContent-Type: x", "garbage\r\n\r\nbody", "HTTP/1.0 abc\r\n\r\n",
    "ICY 200 OK\r\n\r\nbody",
  ])
  func rejectsMalformedResponse(raw: String) {
    #expect(HTTPResponse(Array(raw.utf8)) == nil)
  }

  @Test func emptyBodyIsAllowed() throws {
    let response = try #require(HTTPResponse(Array("HTTP/1.0 204 No Content\r\n\r\n".utf8)))
    #expect(response.body.isEmpty)
  }
}

struct DockerAPITests {
  private let containersJSON = Array(
    """
    [{"Id":"1d0751399dd5f90ab776a9bc0fa67b3e","Names":["/traefik-es-1"],"State":"running"},
     {"Id":"27d46ffe53e6aaaabbbbccccddddeeee","Names":["/labs-postgres-1"]},
     {"Id":"abcdef0123456789","Names":[]}]
    """.utf8)

  private func statsJSON(usage: UInt64, stats: String, total: UInt64, system: UInt64?) -> [UInt8] {
    let systemField = system.map { "\"system_cpu_usage\":\($0)," } ?? ""
    return Array(
      """
      {"name":"/traefik-es-1","cpu_stats":{"cpu_usage":{"total_usage":\(total)},\(systemField)"online_cpus":8},
       "memory_stats":{"usage":\(usage),"stats":{\(stats)},"limit":2147483648},
       "precpu_stats":{"cpu_usage":{"total_usage":0}}}
      """.utf8)
  }

  @Test func parsesContainerNamesWithoutSlash() {
    #expect(
      DockerAPI.containers(fromJSON: containersJSON)?.map(\.name) == [
        "traefik-es-1", "labs-postgres-1", "abcdef012345",
      ])
  }

  @Test func rejectsNonListContainers() {
    #expect(DockerAPI.containers(fromJSON: Array("{\"message\":\"no\"}".utf8)) == nil)
  }

  @Test func memorySubtractsCgroupTwoInactiveFile() {
    let stats = DockerAPI.stats(
      fromJSON: statsJSON(
        usage: 1_715_732_480, stats: "\"inactive_file\":129261568,\"anon\":1", total: 5,
        system: 9))
    #expect(stats?.memory == 1_586_470_912)
  }

  @Test func memorySubtractsCgroupOneInactiveFile() {
    let stats = DockerAPI.stats(
      fromJSON: statsJSON(usage: 1_000, stats: "\"total_inactive_file\":300", total: 5, system: 9))
    #expect(stats?.memory == 700)
  }

  @Test func memoryWithoutCacheFieldIsUsage() {
    let stats = DockerAPI.stats(fromJSON: statsJSON(usage: 1_000, stats: "", total: 5, system: 9))
    #expect(stats?.memory == 1_000)
  }

  @Test func memoryWithCacheAboveUsageIsUsage() {
    let stats = DockerAPI.stats(
      fromJSON: statsJSON(usage: 100, stats: "\"inactive_file\":300", total: 5, system: 9))
    #expect(stats?.memory == 100)
  }

  @Test func rejectsStatsWithoutCPU() {
    #expect(DockerAPI.stats(fromJSON: Array("{\"memory_stats\":{}}".utf8)) == nil)
  }

  @Test func cpuShareComparesWithHostCores() throws {
    let before = try #require(
      DockerAPI.stats(fromJSON: statsJSON(usage: 1, stats: "", total: 1_000, system: 80_000)))
    let after = try #require(
      DockerAPI.stats(fromJSON: statsJSON(usage: 1, stats: "", total: 6_000, system: 160_000)))
    #expect(DockerAPI.cpuShare(previous: before, current: after, hostCores: 10) == 0.05)
  }

  @Test func cpuShareWithoutBaselineIsNil() throws {
    let after = try #require(
      DockerAPI.stats(fromJSON: statsJSON(usage: 1, stats: "", total: 6_000, system: 160_000)))
    #expect(DockerAPI.cpuShare(previous: nil, current: after, hostCores: 10) == nil)
  }

  @Test func cpuShareWhenCountersResetIsNil() throws {
    let before = try #require(
      DockerAPI.stats(fromJSON: statsJSON(usage: 1, stats: "", total: 9_000, system: 80_000)))
    let after = try #require(
      DockerAPI.stats(fromJSON: statsJSON(usage: 1, stats: "", total: 6_000, system: 160_000)))
    #expect(DockerAPI.cpuShare(previous: before, current: after, hostCores: 10) == nil)
  }

  @Test func cpuShareWithoutSystemUsageIsNil() throws {
    let before = try #require(
      DockerAPI.stats(fromJSON: statsJSON(usage: 1, stats: "", total: 1_000, system: nil)))
    let after = try #require(
      DockerAPI.stats(fromJSON: statsJSON(usage: 1, stats: "", total: 6_000, system: nil)))
    #expect(DockerAPI.cpuShare(previous: before, current: after, hostCores: 10) == nil)
  }
}
