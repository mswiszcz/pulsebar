import AppKit
import PulsebarKit
import SwiftUI

enum PanelLayout {
  static let width: CGFloat = 425
}

enum ServerCardLayout {
  static let width = CardDeck.cardWidth(panelWidth: PanelLayout.width)
  static let padding: CGFloat = 14
}

extension ServerSnapshot {
  fileprivate var reading: ServerReading? {
    if case .up(let reading) = state { reading } else { nil }
  }
}

struct ServerCard: View {
  let store: StatsStore
  let id: UUID
  let expand: () -> Void

  var body: some View {
    if let server = store.panel.servers.first(where: { $0.id == id }) {
      VStack(alignment: .leading, spacing: 0) {
        ServerDetails(server: server)
        Divider()
        Glimpse(server: server)
      }
      .frame(width: ServerCardLayout.width, alignment: .leading)
      .transaction { $0.disablesAnimations = true }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(HomelabText.spoken(server))
      .accessibilityAction(named: "Show details", expand)
      .accessibilityAction(named: "Open in browser") { server.openInBrowser() }
    }
  }
}

extension ServerSnapshot {
  fileprivate func openInBrowser() { NSWorkspace.shared.open(config.url) }
}

private struct Glimpse: View {
  let server: ServerSnapshot

  var body: some View {
    HStack(spacing: 6) {
      Circle()
        .fill(server.reading == nil ? Color.secondary : Color.green)
        .frame(width: 7, height: 7)
      Text(server.config.name)
        .font(.callout.weight(.semibold))
        .lineLimit(1)
        .truncationMode(.middle)
        .layoutPriority(1)
      Spacer(minLength: 8)
      trailing
    }
    .monospacedDigit()
    .padding(.horizontal, ServerCardLayout.padding)
    .frame(height: CardDeck.stripHeight)
  }

  @ViewBuilder private var trailing: some View {
    switch server.state {
    case .up(let reading):
      let metrics = reading.metrics
      HStack(spacing: 8) {
        Figure(name: "CPU", fraction: reading.rates.cpuFraction)
        Figure(name: "RAM", fraction: metrics.memoryFraction)
        if let gpu = metrics.fullestGPU {
          Figure(name: "VRAM", fraction: gpu.vramFraction)
        }
        Text(HomelabText.uptime(metrics.uptime))
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      .font(.caption)
    case .unreachable(let lastSeen, _):
      Text(
        lastSeen == nil
          ? "never reached"
          : "unreachable · \(HomelabText.lastSeen(lastSeen, width: .abbreviated))"
      )
      .font(.caption)
      .foregroundStyle(.secondary)
      .lineLimit(1)
    case .unknown:
      Text("—")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }
}

private struct ServerDetails: View {
  let server: ServerSnapshot

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      switch server.state {
      case .up(let reading):
        HomelabTracks(reading: reading, history: server.history)
        VStack(alignment: .leading, spacing: 2) {
          ForEach(HomelabText.details(reading), id: \.self) { DetailNote(text: $0) }
        }
      case .unreachable(_, let reason):
        DetailNote(text: ServerTestResult.reason(reason, url: server.config.url))
      case .unknown:
        DetailNote(text: "Not checked yet")
      }
      Button("Open in browser", action: server.openInBrowser)
        .buttonStyle(.link)
        .font(.subheadline)
    }
    .padding(.horizontal, ServerCardLayout.padding)
    .padding(.top, ServerCardLayout.padding)
    .padding(.bottom, 8)
  }
}

private struct Figure: View {
  let name: String
  let fraction: Double?

  var body: some View {
    let hot = (fraction ?? 0) >= 0.9
    Text("\(name) \(Format.percent(fraction))")
      .fontWeight(hot ? .semibold : nil)
      .foregroundStyle(hot ? Color.orange : Color.secondary)
      .lineLimit(1)
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

  static func spoken(_ server: ServerSnapshot) -> String {
    let name = server.config.name
    switch server.state {
    case .unknown:
      return "\(name), not checked yet"
    case .unreachable(let seen, _):
      return "\(name), unreachable, \(lastSeen(seen, width: .wide))"
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
