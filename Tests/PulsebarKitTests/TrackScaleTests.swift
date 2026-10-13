import PulsebarKit
import Testing

struct TrackScaleTests {
  @Test func abovePeakFloorScalesToSharedPeak() {
    let scaled = TrackScale.squareRootNormalized([[400, 100], [0, nil]], floor: 10)
    #expect(scaled.series == [[1, 0.5], [0, nil]])
    #expect(scaled.fullScale == 400)
  }

  @Test func belowFloorScalesToFloor() {
    let scaled = TrackScale.squareRootNormalized([[25], [1]], floor: 100)
    #expect(scaled.series == [[0.5], [0.1]])
    #expect(scaled.fullScale == 100)
  }

  @Test func withAllZeroWindowStaysFlatAtFloor() {
    let scaled = TrackScale.squareRootNormalized([[0, nil, 0]], floor: 100)
    #expect(scaled.series == [[0, nil, 0]])
    #expect(scaled.fullScale == 100)
  }

  @Test func withoutValuesOrFloorKeepsGaps() {
    let scaled = TrackScale.squareRootNormalized([[nil, nil], []], floor: 0)
    #expect(scaled.series == [[nil, nil], []])
    #expect(scaled.fullScale == 0)
  }
}
