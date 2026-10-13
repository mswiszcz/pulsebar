import AppKit
import PulsebarKit
import SwiftUI

private enum HomelabColumns {
  static let gap: CGFloat = 4
  static let dotSize: CGFloat = 7
  static let cpuWidth: CGFloat = 48
  static let ramWidth: CGFloat = 48
  static let vramWidth: CGFloat = 58
  static let uptimeWidth: CGFloat = 36
  static let detailIndent = AppColumns.disclosureWidth + gap + dotSize + AppColumns.spacing
}

extension ServerSnapshot {
  fileprivate var reading: ServerReading? {
    if case .up(let reading) = state { reading } else { nil }
  }

  fileprivate var isUp: Bool { reading != nil }
}

struct HomelabList: View {
  let servers: [ServerSnapshot]
  @Binding var expanded: UUID?

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text("Homelab")
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, AppColumns.inset)
      ForEach(servers) { server in
        HomelabRow(
          server: server, isExpanded: expanded == server.id,
          toggle: { expanded = expanded == server.id ? nil : server.id })
        if expanded == server.id {
          HomelabDetails(server: server)
        }
      }
    }
  }
}

private struct HomelabRow: View {
  let server: ServerSnapshot
  let isExpanded: Bool
  let toggle: () -> Void

  @State private var isHovered = false

  var body: some View {
    Button(action: toggle) {
      HStack(spacing: AppColumns.spacing) {
        HStack(spacing: HomelabColumns.gap) {
          Image(systemName: "chevron.right")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.secondary)
            .rotationEffect(.degrees(isExpanded ? 90 : 0))
            .frame(width: AppColumns.disclosureWidth)
          Circle()
            .fill(server.isUp ? Color.green : Color.secondary)
            .frame(width: HomelabColumns.dotSize, height: HomelabColumns.dotSize)
        }
        Text(server.config.name)
          .font(.callout)
          .lineLimit(1)
          .truncationMode(.middle)
          .layoutPriority(1)
        content
          .frame(maxWidth: .infinity, alignment: .trailing)
      }
      .monospacedDigit()
      .padding(.horizontal, AppColumns.inset)
      .padding(.vertical, 2)
      .contentShape(Rectangle())
      .background(
        RoundedRectangle(cornerRadius: 6).fill(
          isHovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear))
      )
    }
    .buttonStyle(.plain)
    .onHover { isHovered = $0 }
    .help(tooltip)
    .accessibilityLabel(accessibilityDescription)
    .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
    .accessibilityHint(isExpanded ? "Hides details" : "Shows details")
  }

  @ViewBuilder private var content: some View {
    switch server.state {
    case .unreachable(let lastSeen, _):
      let text =
        lastSeen == nil
        ? "never reached" : "unreachable · \(HomelabText.lastSeen(lastSeen, width: .abbreviated))"
      Text(text)
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    case .unknown, .up:
      let metrics = server.reading?.metrics
      HStack(spacing: HomelabColumns.gap) {
        MetricColumn(
          name: "CPU", fraction: server.reading?.rates.cpuFraction,
          width: HomelabColumns.cpuWidth)
        MetricColumn(
          name: "RAM", fraction: metrics?.memoryFraction, width: HomelabColumns.ramWidth)
        MetricColumn(
          name: "VRAM", fraction: metrics?.fullestGPU?.vramFraction,
          width: HomelabColumns.vramWidth, isAbsent: metrics?.gpus.isEmpty == true)
        Text(HomelabText.uptime(metrics?.uptime))
          .frame(width: HomelabColumns.uptimeWidth, alignment: .trailing)
      }
      .font(.caption)
    }
  }

  private var tooltip: String {
    if case .unreachable(_, let reason) = server.state {
      return ServerTestResult.reason(reason, url: server.config.url)
    }
    return isExpanded ? "Hide details" : "Show details"
  }

  private var accessibilityDescription: String {
    let name = server.config.name
    switch server.state {
    case .unknown:
      return "\(name), not checked yet"
    case .unreachable(let lastSeen, _):
      return "\(name), unreachable, \(HomelabText.lastSeen(lastSeen, width: .wide))"
    case .up(let reading):
      let metrics = reading.metrics
      return [
        name,
        metrics.uptime.map { "up \(Format.duration($0, width: .wide))" },
        reading.rates.cpuFraction.map { "CPU \(Format.percent($0))" },
        metrics.memoryFraction.map { "memory \(Format.percent($0))" },
        metrics.fullestGPU?.vramFraction.map { "VRAM \(Format.percent($0))" },
      ]
      .compactMap { $0 }
      .joined(separator: ", ")
    }
  }
}

private struct MetricColumn: View {
  let name: String
  let fraction: Double?
  let width: CGFloat
  var isAbsent = false

  var body: some View {
    if isAbsent {
      Color.clear.frame(width: width)
    } else {
      let hot = (fraction ?? 0) >= 0.9
      Text("\(name) \(Format.percent(fraction))")
        .fontWeight(hot ? .semibold : nil)
        .foregroundStyle(hot ? Color.orange : Color.secondary)
        .frame(width: width, alignment: .trailing)
    }
  }
}

private struct HomelabDetails: View {
  let server: ServerSnapshot

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      if let reading = server.reading {
        HomelabTracks(reading: reading, history: server.history)
        ForEach(HomelabText.details(reading), id: \.self) { line in
          DetailNote(text: line)
        }
      } else if case .unreachable(_, let reason) = server.state {
        DetailNote(text: ServerTestResult.reason(reason, url: server.config.url))
      } else {
        DetailNote(text: "—")
      }
      Button("Open in browser") { NSWorkspace.shared.open(server.config.url) }
        .buttonStyle(.link)
        .font(.subheadline)
        .padding(.top, 2)
    }
    .padding(.leading, AppColumns.inset + HomelabColumns.detailIndent)
    .padding(.trailing, AppColumns.inset)
    .padding(.bottom, 4)
  }
}

private struct HomelabTracks: View {
  let reading: ServerReading
  let history: [ServerHistorySample]

  var body: some View {
    let metrics = reading.metrics
    VStack(alignment: .leading, spacing: 2) {
      track("CPU", history.map(\.cpu), .blue, reading.rates.cpuFraction)
      track("RAM", history.map(\.memory), .purple, metrics.memoryFraction)
      if metrics.fullestGPU != nil {
        track("GPU", history.map(\.gpuBusy), .pink, metrics.fullestGPU?.busyFraction)
        track("VRAM", history.map(\.vram), .indigo, metrics.fullestGPU?.vramFraction)
      }
    }
  }

  private func track(_ label: String, _ values: [Double?], _ color: Color, _ current: Double?)
    -> some View
  {
    TrackRow(
      label: label,
      graph: TrackGraph(
        capacity: ServerTracker.historyCapacity,
        sampleInterval: ServerTracker.sampleInterval,
        above: TrackSeries(values: values, color: color)),
      accessibilityValue: TrackDescription.describe(
        Format.percent(current), TrackDescription.range(values, Format.percent)),
      height: 24
    ) {
      Text(Format.percent(current))
    }
  }
}

private struct DetailNote: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.subheadline)
      .foregroundStyle(.secondary)
  }
}

private enum HomelabText {
  static func uptime(_ seconds: Double?) -> String {
    seconds.map { "up \(Format.duration($0))" } ?? "—"
  }

  static func lastSeen(_ lastSeen: Double?, width: Duration.UnitsFormatStyle.UnitWidth) -> String {
    guard let lastSeen else { return "never reached" }
    let elapsed = -Date(timeIntervalSince1970: lastSeen).timeIntervalSinceNow
    return "last seen \(Format.duration(elapsed, width: width)) ago"
  }

  static func details(_ reading: ServerReading) -> [String] {
    let metrics = reading.metrics
    let system = [
      joined([loads(metrics), metrics.cores.map { "/ \($0) cores" }], " "),
      metrics.swapUsed.map { "swap \(Format.gigabytes($0)) GB" },
    ]
    let io = [
      rootFree(metrics),
      joined(
        [
          reading.rates.downRate.map { "↓ \(Format.rate($0))" },
          reading.rates.upRate.map { "↑ \(Format.rate($0))" },
        ], " "),
    ]
    let gpus = metrics.gpus.map { gpu in joined([vram(gpu), gtt(gpu)], " · ") }
    return ([joined(system, " · "), joined(io, " · ")] + gpus).compactMap { $0 }
  }

  private static func loads(_ metrics: NodeMetrics) -> String? {
    let values = [metrics.load1, metrics.load5, metrics.load15].compactMap { $0 }
    guard !values.isEmpty else { return nil }
    let text = values.map { $0.formatted(.number.precision(.fractionLength(1))) }
    return "load " + text.joined(separator: " ")
  }

  private static func rootFree(_ metrics: NodeMetrics) -> String? {
    guard let available = metrics.rootAvailable, let size = metrics.rootSize, size > 0 else {
      return nil
    }
    return "/ \(Format.percent(Double(available) / Double(size))) free"
  }

  private static func vram(_ gpu: GPUReading) -> String? {
    guard let used = gpu.vramUsed else { return nil }
    let total = gpu.vramSize.map { "/\(Format.gigabytes($0))" } ?? ""
    return "VRAM \(Format.gigabytes(used))\(total) GB"
  }

  private static func gtt(_ gpu: GPUReading) -> String? {
    gpu.gttUsed.map { "GTT \(Format.gigabytes($0)) GB" }
  }

  private static func joined(_ parts: [String?], _ separator: String) -> String? {
    let present = parts.compactMap { $0 }
    return present.isEmpty ? nil : present.joined(separator: separator)
  }
}
