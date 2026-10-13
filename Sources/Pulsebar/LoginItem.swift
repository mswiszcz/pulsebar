import Observation
import ServiceManagement

@MainActor
@Observable
final class LoginItem {
  private(set) var status = SMAppService.mainApp.status
  private(set) var errorMessage: String?

  var isEnabled: Bool { status == .enabled || status == .requiresApproval }

  func setEnabled(_ enabled: Bool) {
    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
    refresh()
  }

  func refresh() {
    status = SMAppService.mainApp.status
  }
}
