import ServiceManagement
import SwiftUI

struct SettingsView: View {
  let loginItem: LoginItem
  var onEnableNotifications: () -> Void = {}

  @AppStorage(AlertSettings.notifyKey) private var notify = true
  @AppStorage(AlertSettings.thresholdKey) private var threshold = AlertThreshold.warning

  private let appBecameActive = NotificationCenter.default.publisher(
    for: NSApplication.didBecomeActiveNotification)

  var body: some View {
    Form {
      Section {
        Toggle(
          "Launch at login",
          isOn: Binding(get: { loginItem.isEnabled }, set: { loginItem.setEnabled($0) }))
        if loginItem.status == .requiresApproval {
          HStack {
            Text("Approve in System Settings › General › Login Items")
              .foregroundStyle(.secondary)
            Spacer()
            Button("Open Login Items", action: SMAppService.openSystemSettingsLoginItems)
          }
        }
        if let message = loginItem.errorMessage {
          Label(message, systemImage: "exclamationmark.triangle")
            .foregroundStyle(.secondary)
        }
      }
      Section {
        Toggle("Notify when memory is under pressure", isOn: $notify)
        Picker("Notify at", selection: $threshold) {
          ForEach(AlertThreshold.allCases) { Text($0.title).tag($0) }
        }
        .disabled(!notify)
      }
      ServerSettingsSection()
    }
    .formStyle(.grouped)
    .frame(width: 420)
    .fixedSize(horizontal: false, vertical: true)
    .onAppear(perform: loginItem.refresh)
    .onReceive(appBecameActive) { _ in loginItem.refresh() }
    .onChange(of: notify) { _, enabled in
      if enabled { onEnableNotifications() }
    }
  }
}
