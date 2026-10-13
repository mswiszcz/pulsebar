import Darwin
import Foundation

public enum DockerState: Equatable, Sendable {
  case unknown
  case unreachable
  case running([ContainerUsage])
}

public actor DockerMonitor {
  private static let queue = DispatchQueue(label: "dev.mswiszcz.pulsebar.docker")
  private static let maximumResponse = 8 * 1_048_576

  private let socketPaths: [String]
  private let hostCores = ProcessInfo.processInfo.activeProcessorCount
  private var previous: [String: DockerStatsSample] = [:]

  public init(home: String = FileManager.default.homeDirectoryForCurrentUser.path) {
    socketPaths = [home + "/.docker/run/docker.sock", "/var/run/docker.sock"]
  }

  public func sample() async -> DockerState {
    guard let listing = await get("/containers/json"),
      let containers = DockerAPI.containers(fromJSON: listing)
    else { return .unreachable }
    var usages: [ContainerUsage] = []
    var current: [String: DockerStatsSample] = [:]
    for container in containers {
      guard
        let body = await get("/containers/\(container.id)/stats?stream=false&one-shot=true"),
        let stats = DockerAPI.stats(fromJSON: body)
      else { continue }
      current[container.id] = stats
      usages.append(
        ContainerUsage(
          name: container.name, memory: stats.memory,
          cpuShare: DockerAPI.cpuShare(
            previous: previous[container.id], current: stats, hostCores: hostCores)))
    }
    previous = current
    return .running(usages.sorted { $0.memory > $1.memory })
  }

  private func get(_ path: String) async -> [UInt8]? {
    let socketPaths = socketPaths
    return await withCheckedContinuation { continuation in
      Self.queue.async {
        let response = socketPaths.lazy.compactMap { Self.request(path, socketPath: $0) }.first
        continuation.resume(returning: response)
      }
    }
  }

  private static func request(_ path: String, socketPath: String) -> [UInt8]? {
    let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
    guard descriptor >= 0 else { return nil }
    defer { close(descriptor) }
    var timeout = timeval(tv_sec: 2, tv_usec: 0)
    var noSignal: Int32 = 1
    let timeoutSize = socklen_t(MemoryLayout<timeval>.size)
    setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &timeout, timeoutSize)
    setsockopt(descriptor, SOL_SOCKET, SO_SNDTIMEO, &timeout, timeoutSize)
    setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout<Int32>.size))
    guard connect(descriptor, socketPath: socketPath) else { return nil }

    let request = Array("GET \(path) HTTP/1.0\r\nHost: docker\r\n\r\n".utf8)
    var sent = 0
    while sent < request.count {
      let written = request[sent...].withUnsafeBytes {
        send(descriptor, $0.baseAddress, $0.count, 0)
      }
      guard written > 0 else { return nil }
      sent += written
    }

    var response: [UInt8] = []
    var chunk = [UInt8](repeating: 0, count: 65_536)
    while response.count < maximumResponse {
      let received = recv(descriptor, &chunk, chunk.count, 0)
      guard received >= 0 else { return nil }
      if received == 0 { break }
      response += chunk[..<received]
    }
    guard let parsed = HTTPResponse(response), parsed.status == 200 else { return nil }
    return parsed.body
  }

  private static func connect(_ descriptor: Int32, socketPath: String) -> Bool {
    var address = sockaddr_un()
    let pathBytes = Array(socketPath.utf8)
    guard pathBytes.count < MemoryLayout.size(ofValue: address.sun_path) else { return false }
    address.sun_family = sa_family_t(AF_UNIX)
    withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: pathBytes) }
    return withUnsafePointer(to: &address) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        Darwin.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) == 0
      }
    }
  }
}
