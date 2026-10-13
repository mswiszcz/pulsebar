import SwiftUI

@main
struct PulsebarApp: App {
  @State private var store: StatsStore
  @State private var cards: ServerCardStack
  @State private var loginItem = LoginItem()

  init() {
    AlertSettings.registerDefaults()
    let store = StatsStore()
    _store = State(initialValue: store)
    _cards = State(initialValue: ServerCardStack(store: store))
  }

  var body: some Scene {
    MenuBarExtra {
      PopoverView(
        model: store.panel, expandedApp: $store.expandedApp,
        onVisibilityChange: {
          store.isPopoverOpen = $0
          cards.setOpen($0)
        },
        onWindowChange: { cards.attach(to: $0) })
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
