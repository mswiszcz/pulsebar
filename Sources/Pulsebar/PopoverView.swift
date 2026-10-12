import PulsebarKit
import SwiftUI

struct PopoverView: View {
  let stats: Stats?

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      if let stats {
        if let memory = stats.memory {
          MemorySection(memory: memory)
        }
        TopMemorySection(apps: stats.processes.topMemory)
        CPUSection(total: stats.cpuFraction, apps: stats.processes.topCPU)
        DiskSection(disk: stats.disk)
        NetworkSection(network: stats.network)
      } else {
        ProgressView().frame(maxWidth: .infinity)
      }
      Divider()
      HStack {
        Spacer()
        Button("Quit") { NSApplication.shared.terminate(nil) }
          .keyboardShortcut("q")
      }
    }
    .padding(14)
    .frame(width: 320)
  }
}

private struct SectionView<Content: View>: View {
  let title: String
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title).font(.headline)
      content
    }
    .font(.callout)
    .monospacedDigit()
    .labeledContentStyle(TrailingValueStyle())
  }
}

private struct TrailingValueStyle: LabeledContentStyle {
  func makeBody(configuration: Configuration) -> some View {
    HStack {
      configuration.label
      Spacer()
      configuration.content
    }
  }
}

private struct MemorySection: View {
  let memory: MemoryStats

  var body: some View {
    SectionView(title: "Memory") {
      LabeledContent("Pressure") {
        HStack(spacing: 4) {
          Image(nsImage: memory.pressure.dot)
          Text(memory.pressure.title)
        }
      }
      LabeledContent("Available to apps", value: "\(memory.availablePercent)%")
      LabeledContent(
        "Used",
        value: "\(Format.memory(memory.breakdown.used)) of \(Format.memory(memory.total))")
      ProgressView(value: min(memory.usedFraction, 1))
        .tint(Color(nsColor: memory.pressure.color))
      LabeledContent("App memory", value: Format.memory(memory.breakdown.app))
      LabeledContent("Wired", value: Format.memory(memory.breakdown.wired))
      LabeledContent("Compressed", value: Format.memory(memory.breakdown.compressed))
      LabeledContent("Cached files", value: Format.memory(memory.breakdown.cachedFiles))
      LabeledContent(
        "Swap", value: "\(Format.memory(memory.swapUsed)) of \(Format.memory(memory.swapTotal))")
    }
  }
}

private struct AppRow: View {
  let name: String
  let processCount: Int
  let value: String

  var body: some View {
    LabeledContent {
      Text(value)
    } label: {
      HStack(spacing: 4) {
        Text(name).lineLimit(1).truncationMode(.middle)
        if processCount > 1 {
          Text("×\(processCount)").foregroundStyle(.secondary)
        }
      }
    }
  }
}

private struct TopMemorySection: View {
  let apps: [AppUsage<UInt64>]

  var body: some View {
    SectionView(title: "Top memory") {
      ForEach(apps, id: \.name) { app in
        AppRow(name: app.name, processCount: app.processCount, value: Format.memory(app.total))
      }
    }
  }
}

private struct CPUSection: View {
  let total: Double?
  let apps: [AppUsage<Double>]

  var body: some View {
    SectionView(title: "CPU") {
      LabeledContent("Total", value: Format.percent(total))
      ForEach(apps, id: \.name) { app in
        AppRow(
          name: app.name, processCount: app.processCount, value: Format.percent(app.total / 100))
      }
    }
  }
}

private struct DiskSection: View {
  let disk: DiskStats

  var body: some View {
    SectionView(title: "Disk") {
      if let space = disk.space {
        LabeledContent(
          "Free", value: "\(Format.disk(space.available)) of \(Format.disk(space.total))")
      }
      LabeledContent("Read", value: Format.rate(disk.readRate))
      LabeledContent("Write", value: Format.rate(disk.writeRate))
    }
  }
}

private struct NetworkSection: View {
  let network: NetworkStats

  var body: some View {
    SectionView(title: "Network") {
      LabeledContent("Down", value: Format.rate(network.downRate))
      LabeledContent("Up", value: Format.rate(network.upRate))
    }
  }
}
