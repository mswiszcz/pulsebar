import AppKit
import PulsebarKit
import SwiftUI

struct AppsList: View {
  let apps: [AppUsage]

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(spacing: 8) {
        Text("Apps").foregroundStyle(.secondary)
        Spacer()
        Text("Memory").frame(width: AppRow.memoryWidth, alignment: .trailing)
        Text("CPU").frame(width: AppRow.cpuWidth, alignment: .trailing)
      }
      .font(.caption)
      .foregroundStyle(.tertiary)
      .padding(.horizontal, AppRow.inset)
      ForEach(apps, id: \.app) { app in
        AppRow(usage: app)
      }
    }
  }
}

private struct AppRow: View {
  static let memoryWidth: CGFloat = 64
  static let cpuWidth: CGFloat = 40
  static let inset: CGFloat = 6
  static let busyCPUShare = 1 / Double(ProcessInfo.processInfo.activeProcessorCount)

  let usage: AppUsage

  @State private var isHovered = false

  var body: some View {
    Button(action: ActivityMonitor.open) {
      HStack(spacing: 8) {
        AppIcon(bundlePath: usage.app.bundlePath)
        HStack(spacing: 3) {
          Text(usage.app.name).lineLimit(1).truncationMode(.middle)
          if usage.processCount > 1 {
            Text("×\(usage.processCount)").foregroundStyle(.secondary)
          }
        }
        Spacer(minLength: 4)
        Text(Format.appMemory(usage.memory))
          .frame(width: Self.memoryWidth, alignment: .trailing)
        cpu.frame(width: Self.cpuWidth, alignment: .trailing)
      }
      .font(.callout)
      .monospacedDigit()
      .padding(.horizontal, Self.inset)
      .padding(.vertical, 3)
      .contentShape(Rectangle())
      .background(
        RoundedRectangle(cornerRadius: 6).fill(
          isHovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear))
      )
    }
    .buttonStyle(.plain)
    .onHover { isHovered = $0 }
    .help("Open Activity Monitor")
    .accessibilityLabel(accessibilityDescription)
    .accessibilityHint("Opens Activity Monitor")
  }

  private var accessibilityDescription: String {
    let processes = usage.processCount == 1 ? "1 process" : "\(usage.processCount) processes"
    return
      "\(usage.app.name), \(processes), \(Format.appMemory(usage.memory)) memory, \(Format.cpuShare(usage.cpuShare)) CPU"
  }

  @ViewBuilder private var cpu: some View {
    let text = Text(Format.cpuShare(usage.cpuShare))
    if (usage.cpuShare ?? 0) > Self.busyCPUShare {
      text.foregroundStyle(.orange).fontWeight(.semibold)
    } else {
      text.foregroundStyle(.secondary)
    }
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
    .frame(width: 16, height: 16)
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
