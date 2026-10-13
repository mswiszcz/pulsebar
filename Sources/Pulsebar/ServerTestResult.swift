import Foundation
import PulsebarKit

enum ServerTestResult {
  static func message(for result: Result<NodeMetrics, FailureReason>, url: URL) -> String {
    switch result {
    case .success(let metrics): success(metrics)
    case .failure(let failure): reason(failure, url: url)
    }
  }

  static func reason(_ reason: FailureReason, url: URL) -> String {
    switch reason {
    case .timeout: "Timed out after 3 s"
    case .cannotConnect: "Can't connect to \(hostAndPort(url))"
    case .httpStatus(let status): "HTTP \(status)"
    case .bodyTooLarge: "Response over 2 MB"
    case .notNodeExporter: "Not node_exporter (no node_cpu_seconds_total)"
    case .localNetworkDenied:
      "Blocked by Local Network permission — allow Pulsebar in System Settings › Privacy & Security › Local Network"
    case .other(let text): text
    }
  }

  private static func success(_ metrics: NodeMetrics) -> String {
    guard !metrics.gpus.isEmpty else {
      return "OK · no GPU metrics — start node_exporter with --collector.drm"
    }
    let gpus = count(metrics.gpus.count, singular: "GPU", plural: "GPUs")
    guard let cores = metrics.cores else { return "OK · node_exporter, \(gpus)" }
    return "OK · node_exporter, \(count(cores, singular: "core", plural: "cores")), \(gpus)"
  }

  private static func count(_ value: Int, singular: String, plural: String) -> String {
    "\(value) \(value == 1 ? singular : plural)"
  }

  private static func hostAndPort(_ url: URL) -> String {
    let defaultPort = url.scheme == "https" ? 443 : 80
    return "\(url.host() ?? ""):\(url.port ?? defaultPort)"
  }
}
