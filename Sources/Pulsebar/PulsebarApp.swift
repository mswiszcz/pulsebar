import SwiftUI

@main
struct PulsebarApp: App {
  @State private var store = StatsStore()

  var body: some Scene {
    MenuBarExtra {
      PopoverView(stats: store.stats)
    } label: {
      MenuBarLabel(stats: store.stats)
    }
    .menuBarExtraStyle(.window)
  }
}
