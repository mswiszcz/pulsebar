import AppKit
import PulsebarKit
@preconcurrency import UserNotifications

@MainActor
final class PressureNotifier: NSObject, UNUserNotificationCenterDelegate {
  private let center = UNUserNotificationCenter.current()
  var onOpen: () -> Void = {}

  override init() {
    super.init()
    center.delegate = self
  }

  func requestAuthorizationIfNeeded() async {
    guard await center.notificationSettings().authorizationStatus == .notDetermined else {
      return
    }
    _ = try? await center.requestAuthorization(options: [.alert, .sound])
  }

  func post(_ alert: PressureAlert) {
    let content = UNMutableNotificationContent()
    content.title = alert.title
    content.body = alert.body
    content.sound = .default
    center.add(
      UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
  ) async {
    await MainActor.run { onOpen() }
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    [.banner, .list, .sound]
  }
}
