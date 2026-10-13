public struct ScaledTrack: Sendable {
  public let series: [[Double?]]
  public let fullScale: Double
}

public enum TrackScale {
  public static func squareRootNormalized(_ series: [[Double?]], floor: Double) -> ScaledTrack {
    let fullScale = max(series.joined().compactMap { $0 }.max() ?? 0, floor)
    guard fullScale > 0 else {
      return ScaledTrack(series: series.map { $0.map { $0.map { _ in 0 } } }, fullScale: 0)
    }
    return ScaledTrack(
      series: series.map {
        $0.map { $0.map { (max($0, 0) / fullScale).squareRoot() } }
      },
      fullScale: fullScale)
  }
}
