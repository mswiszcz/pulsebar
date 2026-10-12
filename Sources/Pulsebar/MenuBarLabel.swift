import PulsebarKit
import SwiftUI

struct MenuBarLabel: View {
  let stats: Stats?

  var body: some View {
    HStack(spacing: 4) {
      if let memory = stats?.memory {
        Image(nsImage: memory.pressure.dot)
      }
      Text("\(Format.percent(stats?.memory?.usedFraction)) · \(Format.percent(stats?.cpuFraction))")
        .monospacedDigit()
    }
  }
}
