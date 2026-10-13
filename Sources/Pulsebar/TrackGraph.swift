import SwiftUI

struct TrackSeries {
  let values: [Double?]
  let colors: [Color]

  init(values: [Double?], color: Color) {
    self.values = values
    colors = Array(repeating: color, count: values.count)
  }

  init(values: [Double?], colors: [Color]) {
    self.values = values
    self.colors = colors
  }
}

struct TrackGraph: View {
  let capacity: Int
  let sampleInterval: Double
  let above: TrackSeries
  var below: TrackSeries?
  var scaleLabel: String?

  @Environment(\.pixelLength) private var pixel
  @Environment(\.colorSchemeContrast) private var contrast

  var body: some View {
    Canvas { context, size in
      let baseline = below == nil ? size.height : size.height / 2
      draw(above, in: &context, size: size, baseline: baseline, reach: -baseline, emphasis: 1)
      if let below {
        draw(below, in: &context, size: size, baseline: baseline, reach: baseline, emphasis: 0.55)
      }
      let separator = Color(nsColor: .separatorColor)
      context.fill(
        Path(CGRect(x: 0, y: baseline - pixel / 2, width: size.width, height: pixel)),
        with: .color(separator))
      for tick in TimelineAxis.minuteTicks(capacity: capacity, sampleInterval: sampleInterval) {
        context.fill(
          Path(CGRect(x: size.width * tick.fraction, y: 0, width: pixel, height: size.height)),
          with: .color(separator.opacity(0.35)))
      }
      context.fill(
        Path(CGRect(x: size.width - pixel, y: 0, width: pixel, height: size.height)),
        with: .color(separator.opacity(0.6)))
    }
    .overlay(alignment: .topLeading) {
      if let scaleLabel {
        Text(scaleLabel)
          .font(.caption2)
          .monospacedDigit()
          .foregroundStyle(.tertiary)
          .padding(.leading, 2)
      }
    }
  }

  private var fillOpacity: Double { contrast == .increased ? 0.5 : 0.28 }

  private func draw(
    _ series: TrackSeries, in context: inout GraphicsContext, size: CGSize, baseline: CGFloat,
    reach: CGFloat, emphasis: Double
  ) {
    let offset = capacity - series.values.count
    let step = size.width / CGFloat(max(capacity - 1, 1))
    func point(_ index: Int, _ value: Double) -> CGPoint {
      CGPoint(
        x: CGFloat(offset + index) * step,
        y: baseline + reach * CGFloat(min(max(value, 0), 1)))
    }

    for run in runs(of: series) {
      let points = run.indices.map { point($0, series.values[$0] ?? 0) }
      guard let first = points.first, let last = points.last else { continue }
      var line = Path()
      line.addLines(points)
      var area = line
      area.addLine(to: CGPoint(x: last.x, y: baseline))
      area.addLine(to: CGPoint(x: first.x, y: baseline))
      area.closeSubpath()
      context.fill(area, with: .color(run.color.opacity(fillOpacity * emphasis)))
      context.stroke(
        line, with: .color(run.color.opacity(emphasis)),
        style: StrokeStyle(lineWidth: 1, lineJoin: .round))
    }
  }

  private func runs(of series: TrackSeries) -> [(indices: [Int], color: Color)] {
    var runs: [(indices: [Int], color: Color)] = []
    for index in series.values.indices.dropFirst()
    where series.values[index - 1] != nil && series.values[index] != nil {
      let color = series.colors[index]
      if let last = runs.last, last.color == color, last.indices.last == index - 1 {
        runs[runs.count - 1].indices.append(index)
      } else {
        runs.append(([index - 1, index], color))
      }
    }
    return runs
  }
}
