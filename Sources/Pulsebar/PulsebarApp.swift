import SwiftUI

@main
struct PulsebarApp: App {
  @State private var store = StatsStore()

  var body: some Scene {
    MenuBarExtra {
      PopoverView(stats: store.stats, history: store.history)
    } label: {
      MenuBarLabel(stats: store.stats)
    }
    .menuBarExtraStyle(.window)
  }
}
