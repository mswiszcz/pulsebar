import PulsebarKit
import SwiftUI

struct MemoryComposition: View {
  let memory: MemoryStats

  private var segments: [(name: String, bytes: UInt64, color: Color)] {
    [
      ("App", memory.breakdown.app, memory.pressure.color),
      ("Wired", memory.breakdown.wired, .primary.opacity(0.55)),
      ("Compressed", memory.breakdown.compressed, .primary.opacity(0.35)),
      ("Cache", memory.breakdown.cachedFiles, .primary.opacity(0.18)),
    ]
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      GeometryReader { proxy in
        HStack(spacing: 1) {
          ForEach(segments, id: \.name) { segment in
            Rectangle()
              .fill(segment.color)
              .frame(width: proxy.size.width * share(of: segment.bytes))
          }
          Spacer(minLength: 0)
        }
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 2))
      }
      .frame(height: 5)
      HStack(spacing: 6) {
        ForEach(segments, id: \.name) { segment in
          HStack(spacing: 3) {
            Circle().fill(segment.color).frame(width: 5, height: 5)
            Text(legend(for: segment))
          }
        }
      }
      .font(.caption2)
      .monospacedDigit()
      .foregroundStyle(.secondary)
      .lineLimit(1)
      .minimumScaleFactor(0.8)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Memory composition")
    .accessibilityValue(segments.map(legend(for:)).joined(separator: ", "))
  }

  private func legend(for segment: (name: String, bytes: UInt64, color: Color)) -> String {
    let unit = segment.name == segments.last?.name ? " GB" : ""
    return "\(segment.name) \(Format.gigabytes(segment.bytes))\(unit)"
  }

  private func share(of bytes: UInt64) -> CGFloat {
    CGFloat(Double(bytes) / Double(memory.total))
  }
}
