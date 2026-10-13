import SwiftUI

@main
struct PulsebarApp: App {
  @State private var store: StatsStore
  @State private var loginItem = LoginItem()

  init() {
    AlertSettings.registerDefaults()
    _store = State(initialValue: StatsStore())
  }

  var body: some Scene {
    MenuBarExtra {
      PopoverView(model: store.panel, expandedApp: $store.expandedApp) {
        store.isPopoverOpen = $0
      }
    } label: {
      MenuBarLabel(stats: store.stats)
    }
    .menuBarExtraStyle(.window)

    Settings {
      SettingsView(
        loginItem: loginItem, onEnableNotifications: store.requestNotificationAuthorization)
    }
  }
}
