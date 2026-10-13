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

private final class HoverBackgroundView: NSVisualEffectView {
  var onHover: ((Bool) -> Void)?

  override func updateTrackingAreas() {
    trackingAreas.forEach(removeTrackingArea)
    addTrackingArea(
      NSTrackingArea(
        rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    super.updateTrackingAreas()
  }

  override func mouseEntered(with event: NSEvent) { onHover?(true) }

  override func mouseExited(with event: NSEvent) { onHover?(false) }
}

@MainActor
final class ServerCardStack {
  private static let collapseDelay: Duration = .milliseconds(150)
  private static let animationDuration: TimeInterval = 0.18

  private struct Card {
    let window: CardPanel
    let hosting: NSHostingView<ServerCard>
  }

  private let store: StatsStore
  private var panelWindow: NSWindow?
  private var isOpen = false
  private var cards: [UUID: Card] = [:]
  private var slots: [UUID] = []
  private var expanded: UUID?
  private var collapseTask: Task<Void, Never>?
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
    collapseTask?.cancel()
    expanded = nil
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
    if let expanded, !slots.contains(expanded) { self.expanded = nil }
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
      rootView: ServerCard(store: store, id: id) { [weak self] in self?.setExpanded(id) })
    hosting.autoresizingMask = []
    let background = HoverBackgroundView()
    background.material = .menu
    background.state = .active
    background.blendingMode = .behindWindow
    background.wantsLayer = true
    background.layer?.cornerRadius = CardDeck.cornerRadius
    background.layer?.masksToBounds = true
    background.onHover = { [weak self] inside in self?.hoverChanged(id, inside: inside) }
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

  private func frames() -> [UUID: CGRect] {
    guard let panelWindow else { return [:] }
    let collapsed = CardDeck.collapsedFrames(panelFrame: panelWindow.frame, count: slots.count)
    var result = Dictionary(uniqueKeysWithValues: zip(slots, collapsed))
    if let expanded, let card = cards[expanded], let strip = result[expanded] {
      result[expanded] = CardDeck.expandedFrame(
        collapsed: strip, height: card.hosting.frame.height,
        screenMaxY: panelWindow.screen?.visibleFrame.maxY ?? .greatestFiniteMagnitude)
    }
    return result
  }

  private func layout() {
    for card in cards.values {
      card.hosting.frame = CGRect(
        origin: .zero,
        size: CGSize(width: ServerCardLayout.width, height: card.hosting.fittingSize.height))
    }
    for (id, frame) in frames() {
      guard let window = cards[id]?.window, window.frame != frame else { continue }
      window.setFrame(frame, display: true)
      window.invalidateShadow()
    }
  }

  private func hoverChanged(_ id: UUID, inside: Bool) {
    collapseTask?.cancel()
    if inside {
      setExpanded(id)
    } else {
      collapseTask = Task { [weak self] in
        try? await Task.sleep(for: Self.collapseDelay)
        guard !Task.isCancelled, self?.expanded == id else { return }
        self?.setExpanded(nil)
      }
    }
  }

  private func setExpanded(_ id: UUID?) {
    guard expanded != id else { return }
    let previous = expanded
    expanded = id
    let isSwap = id != nil && previous != nil
    if id != nil { restack() }
    let targets = frames()
    for target in [id, previous].compactMap({ $0 }) {
      guard let window = cards[target]?.window, let frame = targets[target] else { continue }
      move(window, to: frame, animated: target == id || !isSwap) { [weak self] in
        if self?.expanded == nil { self?.restack() }
      }
    }
  }

  private func move(
    _ window: CardPanel, to frame: CGRect, animated: Bool,
    completion: @escaping @MainActor @Sendable () -> Void
  ) {
    guard animated, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
      window.setFrame(frame, display: true)
      window.invalidateShadow()
      completion()
      return
    }
    NSAnimationContext.runAnimationGroup { context in
      context.duration = Self.animationDuration
      context.timingFunction = CAMediaTimingFunction(name: .easeOut)
      window.animator().setFrame(frame, display: true)
    } completionHandler: {
      MainActor.assumeIsolated {
        window.invalidateShadow()
        completion()
      }
    }
  }

  private func restack() {
    guard let panelWindow else { return }
    for id in slots {
      if let card = cards[id] { panelWindow.removeChildWindow(card.window) }
    }
    for id in slots.reversed() where id != expanded {
      if let card = cards[id] { panelWindow.addChildWindow(card.window, ordered: .below) }
    }
    if let expanded, let card = cards[expanded] {
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
