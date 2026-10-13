import PulsebarKit

struct PanelModel {
  var stats: Stats?
  var history = RingBuffer<HistorySample>(capacity: TimelineAxis.capacity)
  var growth: [AppIdentity: UInt64] = [:]
  var growthMinutes = 0
  var docker: DockerState = .unknown
  var servers: [ServerSnapshot] = []
}
