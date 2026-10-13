import AppKit
import Observation
import PulsebarKit
import SwiftUI

private final class CardPanel: NSPanel {
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}

private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor
final class ServerCardStack {
  private struct Card {
    let window: CardPanel
    let hosting: NSHostingView<ServerCard>
  }

  private let store: StatsStore
  private var panelWindow: NSWindow?
  private var isOpen = false
  private var cards: [UUID: Card] = [:]
  private var slots: [UUID] = []
  private var front: UUID?
  private var isObserving = false
  private var resizeObserver: (any NSObjectProtocol)?

  init(store: StatsStore) {
    self.store = store
  }

  func attach(to window: NSWindow?) {
    guard window !== panelWindow else { return }
    tearDown()
    panelWindow = window
    resizeObserver = window.map {
      NotificationCenter.default.addObserver(
        forName: NSWindow.didResizeNotification, object: $0, queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated { self?.layout() }
      }
    }
    sync()
  }

  func setOpen(_ isOpen: Bool) {
    self.isOpen = isOpen
    if isOpen { sync() } else { tearDown() }
  }

  private func tearDown() {
    front = nil
    slots = []
    for card in cards.values { discard(card) }
    cards = [:]
  }

  private func discard(_ card: Card) {
    panelWindow?.removeChildWindow(card.window)
    card.window.orderOut(nil)
    card.window.contentView = nil
    card.window.close()
  }

  private func sync() {
    guard isOpen, let panelWindow else { return }
    let servers = store.panel.servers.map(\.id)
    let isRestackNeeded = servers != slots
    slots = servers
    if let front, !slots.contains(front) { self.front = nil }
    for id in cards.keys where !slots.contains(id) {
      discard(cards[id]!)
      cards[id] = nil
    }
    for id in slots where cards[id] == nil {
      cards[id] = makeCard(id, level: panelWindow.level)
    }
    layout()
    if isRestackNeeded { restack() }
    observeStore()
  }

  private func observeStore() {
    guard !isObserving else { return }
    isObserving = true
    withObservationTracking {
      _ = store.panel.servers
    } onChange: { [weak self] in
      Task { @MainActor in
        self?.isObserving = false
        self?.sync()
      }
    }
  }

  private func makeCard(_ id: UUID, level: NSWindow.Level) -> Card {
    let hosting = FirstMouseHostingView(
      rootView: ServerCard(store: store, id: id) { [weak self] in self?.toggleFront(id) })
    hosting.autoresizingMask = [.width, .height]
    let background = NSVisualEffectView()
    background.material = .menu
    background.state = .active
    background.blendingMode = .behindWindow
    background.wantsLayer = true
    background.layer?.cornerRadius = ServerCardLayout.cornerRadius
    background.layer?.masksToBounds = true
    background.addSubview(hosting)

    let window = CardPanel(
      contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered,
      defer: false)
    window.becomesKeyOnlyIfNeeded = true
    window.hidesOnDeactivate = false
    window.isReleasedWhenClosed = false
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = true
    window.level = level
    window.contentView = background
    return Card(window: window, hosting: hosting)
  }

  private func layout() {
    guard let panelWindow else { return }
    let ordered = slots.compactMap { cards[$0] }
    let sizes = ordered.map {
      CGSize(width: ServerCardLayout.width, height: $0.hosting.fittingSize.height)
    }
    let frames = CardFan.frames(
      panelFrame: panelWindow.frame, cardSizes: sizes,
      screenMinX: panelWindow.screen?.visibleFrame.minX ?? -.greatestFiniteMagnitude)
    for (card, frame) in zip(ordered, frames) where card.window.frame != frame {
      card.window.setFrame(frame, display: true)
      card.window.invalidateShadow()
    }
  }

  private func toggleFront(_ id: UUID) {
    front = front == id ? nil : id
    restack()
  }

  private func restack() {
    guard let panelWindow else { return }
    for id in slots {
      if let card = cards[id] { panelWindow.removeChildWindow(card.window) }
    }
    for id in slots.reversed() where id != front {
      if let card = cards[id] { panelWindow.addChildWindow(card.window, ordered: .below) }
    }
    if let front, let card = cards[front] {
      panelWindow.addChildWindow(card.window, ordered: .above)
    }
  }
}

struct PanelWindowReader: NSViewRepresentable {
  let onChange: (NSWindow?) -> Void

  func makeNSView(context: Context) -> NSView { WindowReportingView(onChange: onChange) }

  func updateNSView(_ view: NSView, context: Context) {}

  private final class WindowReportingView: NSView {
    let onChange: (NSWindow?) -> Void

    init(onChange: @escaping (NSWindow?) -> Void) {
      self.onChange = onChange
      super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      onChange(window)
    }
  }
}
