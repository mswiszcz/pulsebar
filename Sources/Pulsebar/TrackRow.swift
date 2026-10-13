import SwiftUI

enum TrackLayout {
  static let labelWidth: CGFloat = 50
  static let valueWidth: CGFloat = 84
  static let spacing: CGFloat = 8
  static let graphHeight: CGFloat = 40
}

enum TimelineAxis {
  static let capacity = 150
  static let sampleInterval = 2.0

  static func minuteTicks(
    capacity: Int, sampleInterval: Double
  ) -> [(minutesAgo: Int, fraction: CGFloat)] {
    let last = capacity - 1
    let samplesPerMinute = Int(60 / sampleInterval)
    return (1...4).compactMap { minutes in
      let slot = last - minutes * samplesPerMinute
      return slot > 0 ? (minutes, CGFloat(slot) / CGFloat(last)) : nil
    }
  }
}

struct TrackRow<Value: View>: View {
  let label: String
  let graph: TrackGraph
  let accessibilityValue: String
  var height: CGFloat = TrackLayout.graphHeight
  @ViewBuilder let value: Value

  var body: some View {
    HStack(spacing: TrackLayout.spacing) {
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(width: TrackLayout.labelWidth, alignment: .leading)
      graph
      value
        .font(.callout)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .frame(width: TrackLayout.valueWidth, alignment: .trailing)
    }
    .frame(height: height)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(label)
    .accessibilityValue(accessibilityValue)
  }
}

enum TrackDescription {
  static func describe(_ current: String, _ window: String) -> String {
    "\(current), 5-minute range \(window)"
  }

  static func range(_ values: [Double?], _ format: (Double?) -> String) -> String {
    let known = values.compactMap { $0 }
    guard let low = known.min(), let high = known.max() else { return "not available yet" }
    return "\(format(low))–\(format(high))"
  }
}

struct DirectionalValue: View {
  let marker: Text
  let text: String

  var body: some View {
    HStack(spacing: 3) {
      marker
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(text)
    }
  }
}

struct ValueCaption: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.caption2)
      .foregroundStyle(.secondary)
  }
}

struct TimeRuler: View {
  var body: some View {
    HStack(spacing: TrackLayout.spacing) {
      Color.clear.frame(width: TrackLayout.labelWidth, height: 0)
      HStack {
        Text("5 min")
        Spacer()
        Text("now")
      }
      Color.clear.frame(width: TrackLayout.valueWidth, height: 0)
    }
    .frame(height: 12)
    .font(.caption2)
    .foregroundStyle(.tertiary)
    .accessibilityHidden(true)
  }
}
