import AppKit
import Observation
import PulsebarKit
import SwiftUI

private final class CardPanel: NSPanel {
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}

private final class DeckHostingView: NSHostingView<ServerDeck> {
  var onPointer: ((CGPoint?) -> Void)?

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

  override func updateTrackingAreas() {
    trackingAreas.forEach(removeTrackingArea)
    addTrackingArea(
      NSTrackingArea(
        rect: .zero,
        options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
        owner: self))
    super.updateTrackingAreas()
  }

  override func mouseEntered(with event: NSEvent) { report(event) }

  override func mouseMoved(with event: NSEvent) { report(event) }

  override func mouseExited(with event: NSEvent) { onPointer?(nil) }

  private func report(_ event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    onPointer?(CGPoint(x: point.x, y: isFlipped ? point.y : bounds.height - point.y))
  }
}

@MainActor
final class ServerCardStack {
  private static let collapseDelay: Duration = .milliseconds(150)
  private static let animationDuration = 0.18

  private let store: StatsStore
  private let state = DeckState()
  private var panelWindow: NSWindow?
  private var window: CardPanel?
  private var height: CGFloat = 0
  private var isOpen = false
  private var isObserving = false
  private var collapseTask: Task<Void, Never>?
  private var settleTask: Task<Void, Never>?
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
        MainActor.assumeIsolated { self?.place() }
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
    settleTask?.cancel()
    state.open = nil
    state.detailsCap = nil
    state.frames = [:]
    guard let window else { return }
    panelWindow?.removeChildWindow(window)
    window.orderOut(nil)
    window.contentView = nil
    window.close()
    self.window = nil
  }

  private func sync() {
    guard isOpen, let panelWindow else { return }
    let servers = store.panel.servers.map(\.id)
    if let open = state.open, !servers.contains(open) { state.open = nil }
    if servers.isEmpty {
      tearDown()
    } else {
      if window == nil { window = makeWindow(level: panelWindow.level) }
      if settleTask == nil { fit() }
    }
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

  private func makeWindow(level: NSWindow.Level) -> CardPanel {
    let hosting = DeckHostingView(rootView: makeDeck(state: state))
    hosting.sizingOptions = []
    hosting.onPointer = { [weak self] in self?.pointerMoved($0) }

    let window = CardPanel(
      contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered,
      defer: false)
    window.becomesKeyOnlyIfNeeded = true
    window.hidesOnDeactivate = false
    window.isReleasedWhenClosed = false
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = false
    window.acceptsMouseMovedEvents = true
    window.level = level
    window.contentView = hosting
    self.window = window
    height = layoutHeight(open: state.open).height
    panelWindow?.addChildWindow(window, ordered: .below)
    place()
    return window
  }

  private func makeDeck(state: DeckState) -> ServerDeck {
    ServerDeck(store: store, state: state) { [weak self] in self?.toggle($0) }
  }

  private func fittingHeight(open id: UUID?) -> CGFloat {
    NSHostingView(rootView: makeDeck(state: DeckState(open: id))).fittingSize.height
  }

  private func layoutHeight(open id: UUID?) -> (height: CGFloat, cap: CGFloat?) {
    let natural = fittingHeight(open: id)
    guard let panelFrame = panelWindow?.frame else { return (natural, nil) }
    let limit = CardDeck.maxHeight(
      panelFrame: panelFrame,
      screenMinY: panelWindow?.screen?.visibleFrame.minY ?? -.greatestFiniteMagnitude)
    guard natural > limit else { return (natural, nil) }
    return (limit, limit - fittingHeight(open: nil) - 1)
  }

  private func place() {
    guard let panelWindow, let window else { return }
    window.setFrame(
      CardDeck.windowFrame(panelFrame: panelWindow.frame, height: height), display: true)
  }

  private func fit() {
    height = layoutHeight(open: state.open).height
    place()
  }

  private func pointerMoved(_ point: CGPoint?) {
    collapseTask?.cancel()
    let hit = point.flatMap { point in
      store.panel.servers.map(\.id).first { state.frames[$0]?.contains(point) == true }
    }
    if let hit {
      setOpen(hit)
    } else {
      collapseTask = Task { [weak self] in
        try? await Task.sleep(for: Self.collapseDelay)
        guard !Task.isCancelled else { return }
        self?.setOpen(nil)
      }
    }
  }

  private func toggle(_ id: UUID) {
    setOpen(state.open == id ? nil : id)
  }

  private func setOpen(_ id: UUID?) {
    guard state.open != id else { return }
    settleTask?.cancel()
    let target = layoutHeight(open: id)
    state.detailsCap = target.cap
    if target.height > height {
      height = target.height
      place()
    }
    let isAnimated = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    withAnimation(isAnimated ? .easeOut(duration: Self.animationDuration) : nil) {
      state.open = id
    }
    settleTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(isAnimated ? Self.animationDuration : 0))
      guard !Task.isCancelled else { return }
      self?.height = target.height
      self?.place()
      self?.settleTask = nil
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
