import AppKit
import PulsebarKit
import SwiftUI

enum AppColumns {
  static let disclosureWidth: CGFloat = 9
  static let iconSize: CGFloat = 16
  static let memoryWidth: CGFloat = 64
  static let cpuWidth: CGFloat = 40
  static let inset: CGFloat = 6
  static let spacing: CGFloat = 8
  static let gap: CGFloat = 6
  static let listHeight: CGFloat = 216
  static var detailIndent: CGFloat { disclosureWidth + gap + iconSize + spacing }
  static let busyCPUShare = 1 / Double(ProcessInfo.processInfo.activeProcessorCount)
}

struct AppsList: View {
  let apps: [AppUsage]
  let details: [AppIdentity: [ProcessDetail]]
  let growth: [AppIdentity: UInt64]
  let growthMinutes: Int
  let docker: DockerState
  @Binding var expanded: AppIdentity?

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(spacing: AppColumns.spacing) {
        Text("Apps").foregroundStyle(.secondary)
        Spacer()
        Text("Memory").frame(width: AppColumns.memoryWidth, alignment: .trailing)
        Text("CPU").frame(width: AppColumns.cpuWidth, alignment: .trailing)
      }
      .font(.caption)
      .foregroundStyle(.secondary)
      .padding(.horizontal, AppColumns.inset)
      ScrollView {
        VStack(alignment: .leading, spacing: 2) {
          ForEach(apps, id: \.app) { app in
            AppRow(
              usage: app,
              growth: growth[app.app],
              growthMinutes: growthMinutes,
              isExpanded: expanded == app.app,
              toggle: { expanded = expanded == app.app ? nil : app.app })
            if expanded == app.app {
              AppDetails(app: app.app, processes: details[app.app], docker: docker)
            }
          }
        }
      }
      .frame(height: AppColumns.listHeight)
    }
  }
}

private struct AppRow: View {
  let usage: AppUsage
  let growth: UInt64?
  let growthMinutes: Int
  let isExpanded: Bool
  let toggle: () -> Void

  @State private var isHovered = false

  var body: some View {
    Button(action: toggle) {
      HStack(spacing: AppColumns.spacing) {
        HStack(spacing: AppColumns.gap) {
          Image(systemName: "chevron.right")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.secondary)
            .rotationEffect(.degrees(isExpanded ? 90 : 0))
            .frame(width: AppColumns.disclosureWidth)
          AppIcon(bundlePath: usage.app.bundlePath)
        }
        HStack(spacing: 3) {
          Text(usage.app.name).lineLimit(1).truncationMode(.middle)
          if usage.processCount > 1 {
            Text("×\(usage.processCount)").foregroundStyle(.secondary).fixedSize()
          }
        }
        .layoutPriority(1)
        Spacer(minLength: 4)
        if let growth {
          GrowthBadge(bytes: growth, minutes: growthMinutes)
        }
        Text(Format.appMemory(usage.memory))
          .frame(width: AppColumns.memoryWidth, alignment: .trailing)
        CPUValue(share: usage.cpuShare).frame(width: AppColumns.cpuWidth, alignment: .trailing)
      }
      .font(.callout)
      .monospacedDigit()
      .padding(.horizontal, AppColumns.inset)
      .padding(.vertical, 3)
      .contentShape(Rectangle())
      .background(
        RoundedRectangle(cornerRadius: 6).fill(
          isHovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear))
      )
    }
    .buttonStyle(.plain)
    .onHover { isHovered = $0 }
    .help(isExpanded ? "Hide processes" : "Show processes")
    .accessibilityLabel(accessibilityDescription)
    .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
    .accessibilityHint(isExpanded ? "Hides processes" : "Shows processes")
  }

  private var accessibilityDescription: String {
    let processes = usage.processCount == 1 ? "1 process" : "\(usage.processCount) processes"
    let parts = [
      usage.app.name, processes, "\(Format.appMemory(usage.memory)) memory",
      "\(Format.cpuShare(usage.cpuShare)) CPU",
      growth.map { "grew \(Format.appMemory($0)) in \(growthMinutes) minutes" },
    ]
    return parts.compactMap { $0 }.joined(separator: ", ")
  }
}

private struct GrowthBadge: View {
  let bytes: UInt64
  let minutes: Int

  var body: some View {
    ViewThatFits(in: .horizontal) {
      Text(Format.growth(bytes, minutes: minutes))
      Text("+\(Format.appMemory(bytes))")
    }
    .font(.caption)
    .foregroundStyle(.orange)
    .lineLimit(1)
  }
}

private struct CPUValue: View {
  let share: Double?

  var body: some View {
    let text = Text(Format.cpuShare(share))
    if (share ?? 0) > AppColumns.busyCPUShare {
      text.foregroundStyle(.orange).fontWeight(.semibold)
    } else {
      text.foregroundStyle(.secondary)
    }
  }
}

private struct AppDetails: View {
  let app: AppIdentity
  let processes: [ProcessDetail]?
  let docker: DockerState

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      if app.isDocker {
        containers
      } else if let processes {
        ForEach(processes, id: \.id) { process in
          DetailRow(
            label: process.label,
            caption: process.started.map { Format.uptime(since: $0) },
            memory: process.memory, cpuShare: process.cpuShare)
        }
      } else {
        DetailNote(text: "—")
      }
      Button("Open in Activity Monitor", action: ActivityMonitor.open)
        .buttonStyle(.link)
        .font(.subheadline)
        .padding(.top, 2)
    }
    .padding(.leading, AppColumns.inset + AppColumns.detailIndent)
    .padding(.trailing, AppColumns.inset)
    .padding(.bottom, 4)
  }

  @ViewBuilder private var containers: some View {
    switch docker {
    case .unknown:
      DetailNote(text: "Reading containers…")
    case .unreachable:
      DetailNote(text: "Docker not reachable")
    case .running(let containers) where containers.isEmpty:
      DetailNote(text: "No running containers")
    case .running(let containers):
      ForEach(containers.prefix(8), id: \.name) { container in
        DetailRow(
          label: container.name, caption: nil, memory: container.memory,
          cpuShare: container.cpuShare)
      }
    }
  }
}

private struct DetailRow: View {
  let label: String
  let caption: String?
  let memory: UInt64
  let cpuShare: Double?

  var body: some View {
    HStack(spacing: AppColumns.spacing) {
      HStack(spacing: 3) {
        Text(label).lineLimit(1).truncationMode(.middle)
        if let caption {
          Text("· \(caption)").foregroundStyle(.secondary).fixedSize()
        }
      }
      Spacer(minLength: 4)
      Text(Format.appMemory(memory))
        .frame(width: AppColumns.memoryWidth, alignment: .trailing)
      CPUValue(share: cpuShare).frame(width: AppColumns.cpuWidth, alignment: .trailing)
    }
    .font(.subheadline)
    .monospacedDigit()
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      [
        label, caption.map { "up \($0)" }, "\(Format.appMemory(memory)) memory",
        "\(Format.cpuShare(cpuShare)) CPU",
      ].compactMap { $0 }.joined(separator: ", "))
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

private struct AppIcon: View {
  let bundlePath: String?

  var body: some View {
    Group {
      if let bundlePath {
        Image(nsImage: AppIcons.icon(for: bundlePath)).resizable()
      } else {
        Image(systemName: "terminal")
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
      }
    }
    .frame(width: AppColumns.iconSize, height: AppColumns.iconSize)
  }
}

@MainActor
enum AppIcons {
  private static var cache: [String: NSImage] = [:]

  static func icon(for bundlePath: String) -> NSImage {
    if let icon = cache[bundlePath] { return icon }
    let icon = NSWorkspace.shared.icon(forFile: bundlePath)
    cache[bundlePath] = icon
    return icon
  }
}

@MainActor
enum ActivityMonitor {
  static func open() {
    guard
      let url = NSWorkspace.shared.urlForApplication(
        withBundleIdentifier: "com.apple.ActivityMonitor")
    else { return }
    NSWorkspace.shared.openApplication(
      at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
  }
}
