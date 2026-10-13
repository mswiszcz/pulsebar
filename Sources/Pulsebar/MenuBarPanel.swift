import AppKit

@MainActor
enum MenuBarPanel {
  static func open() {
    NSApp.activate()
    NSApp.windows.lazy.compactMap { $0.contentView.flatMap(statusButton(in:)) }.first?
      .performClick(nil)
  }

  private static func statusButton(in view: NSView) -> NSStatusBarButton? {
    view as? NSStatusBarButton ?? view.subviews.lazy.compactMap(statusButton(in:)).first
  }
}
