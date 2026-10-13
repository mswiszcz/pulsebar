import PulsebarKit
import SwiftUI

struct PopoverView: View {
  let model: PanelModel
  @Binding var expandedApp: AppIdentity?
  var onVisibilityChange: (Bool) -> Void = { _ in }

  @Environment(\.openSettings) private var openSettings

  private var stats: Stats? { model.stats }
  private var history: RingBuffer<HistorySample> { model.history }

  private static let diskFloor = 1_000_000.0
  private static let networkFloor = 100_000.0

  private var samples: [HistorySample] { history.elements }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 8) {
        header
        if let memory = stats?.memory {
          MemoryComposition(memory: memory)
        }
      }
      Divider()
      VStack(alignment: .leading, spacing: 6) {
        pressureTrack
        cpuTrack
        diskTrack
        networkTrack
        TimeRuler()
      }
      if let apps = stats?.apps, !apps.isEmpty {
        Divider()
        AppsList(
          apps: apps, details: stats?.processes.details ?? [:], growth: model.growth,
          growthMinutes: model.growthMinutes, docker: model.docker, expanded: $expandedApp)
      }
      Divider()
      HStack {
        Text("Updated every 2 s")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        Button(action: showSettings) {
          Image(systemName: "gearshape")
        }
        .buttonStyle(.borderless)
        .keyboardShortcut(",")
        .help("Settings")
        .accessibilityLabel("Settings")
        Button("Quit") { NSApplication.shared.terminate(nil) }
          .keyboardShortcut("q")
          .controlSize(.small)
      }
    }
    .padding(14)
    .frame(width: 340)
    .transaction { $0.disablesAnimations = true }
    .onAppear { onVisibilityChange(true) }
    .onDisappear { onVisibilityChange(false) }
  }

  private func showSettings() {
    NSApp.activate()
    openSettings()
    NSApp.activate()
  }

  private var header: some View {
    HStack(spacing: 8) {
      Circle()
        .fill(stats?.memory?.pressure.color ?? Color.secondary)
        .frame(width: 10, height: 10)
      Text(stats?.memory?.pressure.verdict ?? "Memory")
        .font(.title3.weight(.semibold))
      Spacer()
      if let memory = stats?.memory {
        VStack(alignment: .trailing, spacing: 0) {
          Text("\(Format.percent(memory.usedFraction)) used")
            .foregroundStyle(.secondary)
          Text("Swap \(Format.memory(memory.swapUsed))")
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .monospacedDigit()
      }
    }
    .accessibilityElement(children: .combine)
  }

  private var pressureTrack: some View {
    let values = samples.map(\.pressureFraction)
    return TrackRow(
      label: "Pressure",
      graph: TrackGraph(
        capacity: history.capacity,
        above: TrackSeries(values: values, colors: samples.map { ($0.pressure ?? .normal).color })
      ),
      accessibilityValue: describe(
        Format.percent(values.last ?? nil), range(values, Format.percent))
    ) {
      VStack(alignment: .trailing, spacing: 0) {
        Text(Format.percent(values.last ?? nil))
        ValueCaption(text: "pressure")
      }
    }
  }

  private var cpuTrack: some View {
    let values = samples.map(\.cpuFraction)
    return TrackRow(
      label: "CPU",
      graph: TrackGraph(
        capacity: history.capacity, above: TrackSeries(values: values, color: .blue)),
      accessibilityValue: describe(
        Format.percent(stats?.cpuFraction), range(values, Format.percent))
    ) {
      VStack(alignment: .trailing, spacing: 0) {
        Text(Format.percent(stats?.cpuFraction))
        ValueCaption(text: "all cores")
      }
    }
  }

  private var diskTrack: some View {
    let reads = samples.map(\.diskRead)
    let writes = samples.map(\.diskWrite)
    let scaled = TrackScale.squareRootNormalized([reads, writes], floor: Self.diskFloor)
    let current =
      "read \(Format.rate(stats?.disk.readRate)), write \(Format.rate(stats?.disk.writeRate))"
    let window = "read \(range(reads, Format.rate)), write \(range(writes, Format.rate))"
    return TrackRow(
      label: "Disk",
      graph: TrackGraph(
        capacity: history.capacity,
        above: TrackSeries(values: scaled.series[0], color: .orange),
        below: TrackSeries(values: scaled.series[1], color: .orange),
        scaleLabel: Format.rate(scaled.fullScale)),
      accessibilityValue: describe(current, window)
    ) {
      VStack(alignment: .trailing, spacing: 0) {
        DirectionalValue(marker: Text("R"), text: Format.rate(stats?.disk.readRate))
        DirectionalValue(marker: Text("W"), text: Format.rate(stats?.disk.writeRate))
        if let space = stats?.disk.space {
          ValueCaption(text: "\(Format.disk(space.available)) free")
        }
      }
    }
  }

  private var networkTrack: some View {
    let downs = samples.map(\.networkDown)
    let ups = samples.map(\.networkUp)
    let scaled = TrackScale.squareRootNormalized([downs, ups], floor: Self.networkFloor)
    let current =
      "down \(Format.rate(stats?.network.downRate)), up \(Format.rate(stats?.network.upRate))"
    let window = "down \(range(downs, Format.rate)), up \(range(ups, Format.rate))"
    return TrackRow(
      label: "Network",
      graph: TrackGraph(
        capacity: history.capacity,
        above: TrackSeries(values: scaled.series[0], color: .teal),
        below: TrackSeries(values: scaled.series[1], color: .teal),
        scaleLabel: Format.rate(scaled.fullScale)),
      accessibilityValue: describe(current, window)
    ) {
      VStack(alignment: .trailing, spacing: 0) {
        DirectionalValue(
          marker: Text(Image(systemName: "arrow.down")), text: Format.rate(stats?.network.downRate))
        DirectionalValue(
          marker: Text(Image(systemName: "arrow.up")), text: Format.rate(stats?.network.upRate))
      }
    }
  }

  private func describe(_ current: String, _ window: String) -> String {
    "\(current), 5-minute range \(window)"
  }

  private func range(_ values: [Double?], _ format: (Double?) -> String) -> String {
    let known = values.compactMap { $0 }
    guard let low = known.min(), let high = known.max() else { return "not available yet" }
    return "\(format(low))–\(format(high))"
  }
}
