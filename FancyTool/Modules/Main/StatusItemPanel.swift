import AppKit
import SwiftUI

enum StatusItemPanelPlacement {
  static func frame(size: NSSize, anchor: NSRect, visibleFrame: NSRect) -> NSRect {
    let available = visibleFrame.insetBy(dx: 8, dy: 8)
    let size = NSSize(width: min(size.width, available.width), height: min(size.height, available.height))
    let x = min(max(anchor.midX - size.width / 2, available.minX), available.maxX - size.width)
    let y = min(max(anchor.minY - size.height - 6, available.minY), available.maxY - size.height)
    return NSRect(origin: NSPoint(x: x, y: y), size: size)
  }
}

enum StatusItemPanelDismissal {
  static func shouldClose(at point: NSPoint, panelFrame: NSRect, anchorFrame: NSRect?) -> Bool {
    !panelFrame.contains(point) && !(anchorFrame?.contains(point) ?? false)
  }
}

/// Owns menu-bar panel presentation, sizing and dismissal. The anchor is sampled
/// on open only: editing status text cannot move the panel.
@MainActor
final class StatusItemPanel: NSObject {
  private static weak var activePanel: StatusItemPanel?
  private static let cornerRadius: CGFloat = 12
  private static let cornerMask: NSImage = {
    let radius = cornerRadius
    let size = NSSize(width: radius * 2 + 1, height: radius * 2 + 1)
    let image = NSImage(size: size, flipped: false) { rect in
      NSColor.black.setFill()
      NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
      return true
    }
    image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
    image.resizingMode = .stretch
    return image
  }()

  private let panel: MenuBarPanel
  private var contentSize: NSSize
  private let resizesContent: Bool
  private var presentationAnchor: NSRect?
  private var presentationVisibleFrame: NSRect?
  private var resizeWork: DispatchWorkItem?
  private weak var anchor: NSStatusBarButton?
  private var localMouseMonitor: Any?
  private var globalMouseMonitor: Any?
  private var observers: [(NotificationCenter, NSObjectProtocol)] = []

  var onClose: (() -> Void)?
  var onShow: ((NSWindow) -> Void)?

  var isShown: Bool { panel.isVisible }

  init(size: NSSize, content: some View, contentPadding: CGFloat = 16, resizesContent: Bool = false) {
    contentSize = size
    self.resizesContent = resizesContent
    panel = MenuBarPanel(
      contentRect: NSRect(origin: .zero, size: size),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    super.init()

    panel.isReleasedWhenClosed = false
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.level = .popUpMenu
    panel.animationBehavior = .none
    panel.hidesOnDeactivate = false
    panel.isMovable = false
    panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .ignoresCycle]
    panel.onDismiss = { [weak self] in self?.close() }

    // A transparent root keeps the material separate from the window background.
    let container = NSView(frame: NSRect(origin: .zero, size: size))
    container.wantsLayer = true
    container.layer?.backgroundColor = NSColor.clear.cgColor

    let sizedContent = resizesContent
      ? AnyView(content.padding(contentPadding).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading))
      : AnyView(content.padding(contentPadding).frame(width: size.width, height: size.height, alignment: .topLeading))
    let surface: NSView
    if #available(macOS 26.0, *) {
      panel.hasShadow = false
      let clippedGlass = NSView(frame: container.bounds)
      clippedGlass.wantsLayer = true
      clippedGlass.layer?.cornerRadius = Self.cornerRadius
      clippedGlass.layer?.masksToBounds = true
      clippedGlass.autoresizingMask = [.width, .height]
      // Keep the native glass edge outside the visible rounded surface.
      // Matching content padding preserves the panel's original layout.
      let edgeInset: CGFloat = 4
      let glass = PopupGlassSurface.make(
        content: sizedContent.padding(edgeInset),
        frame: clippedGlass.bounds.insetBy(dx: -edgeInset, dy: -edgeInset),
        cornerRadius: Self.cornerRadius + edgeInset
      )
      if resizesContent { glass.autoresizingMask = [.width, .height] }
      clippedGlass.addSubview(glass)
      surface = clippedGlass
    } else {
      container.layer?.cornerRadius = Self.cornerRadius
      container.layer?.masksToBounds = true
      let background = NSVisualEffectView(frame: container.bounds)
      background.material = .popover
      background.blendingMode = .behindWindow
      background.state = .active
      background.autoresizingMask = [.width, .height]
      // Behind-window materials need their own mask, in addition to view clipping.
      background.maskImage = Self.cornerMask
      container.addSubview(background)

      let host = NSHostingView(rootView: sizedContent)
      // AppKit owns the panel size. SwiftUI may update its content, never its window.
      host.sizingOptions = []
      host.frame = container.bounds
      host.autoresizingMask = [.width, .height]
      surface = host
    }
    container.addSubview(surface)
    panel.contentView = container
    panel.setContentSize(size)
    surface.frame = container.bounds
    surface.layoutSubtreeIfNeeded()
  }

  func toggle(relativeTo button: NSStatusBarButton) {
    if isShown { close() } else { show(relativeTo: button) }
  }

  /// Opt-in resizing preserves the original menu-bar anchor and grows downward.
  func setContentSize(_ size: NSSize) {
    guard resizesContent, size.width.isFinite, size.height.isFinite,
          size.width > 0, size.height > 0, size != contentSize else { return }
    contentSize = size
    guard isShown, resizeWork == nil else { return }
    // SwiftUI can request a size from onChange while updating its view graph.
    // Finish that update before AppKit resizes the host; coalesce to the latest size.
    let work = DispatchWorkItem { [weak self] in
      guard let self else { return }
      self.resizeWork = nil
      guard self.isShown, let anchor = self.presentationAnchor,
            let visibleFrame = self.presentationVisibleFrame else { return }
      let frame = StatusItemPanelPlacement.frame(size: self.contentSize, anchor: anchor, visibleFrame: visibleFrame)
      if self.panel.frame != frame { self.panel.setFrame(frame, display: true) }
    }
    resizeWork = work
    DispatchQueue.main.async(execute: work)
  }

  func show(relativeTo button: NSStatusBarButton) {
    guard !isShown, let window = button.window, let screen = window.screen else { return }
    Self.activePanel?.close()
    Self.activePanel = self
    anchor = button

    let anchorFrame = window.convertToScreen(button.convert(button.bounds, to: nil))
    presentationAnchor = anchorFrame
    presentationVisibleFrame = screen.visibleFrame
    panel.setFrame(StatusItemPanelPlacement.frame(size: contentSize, anchor: anchorFrame, visibleFrame: screen.visibleFrame), display: false)
    button.highlight(true)
    installDismissalHandlers()
    panel.makeKeyAndOrderFront(nil)
    DispatchQueue.main.async { [weak self] in
      guard let self, self.isShown else { return }
      self.onShow?(self.panel)
    }
  }

  func close() {
    let wasShown = isShown
    resizeWork?.cancel()
    resizeWork = nil
    removeDismissalHandlers()
    panel.orderOut(nil)
    anchor?.highlight(false)
    anchor = nil
    presentationAnchor = nil
    presentationVisibleFrame = nil
    if Self.activePanel === self { Self.activePanel = nil }
    if wasShown { onClose?() }
  }

  private func installDismissalHandlers() {
    let events: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
    localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: events) { [weak self] event in
      MainActor.assumeIsolated { () -> Void in
        guard let self else { return }
        if event.window === self.panel { return }
        self.dismissIfOutside(at: NSEvent.mouseLocation)
      }
      return event
    }
    globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: events) { [weak self] _ in
      // Status-bar clicks can arrive through SystemUIServer as global events.
      // Preserve the open state until the button's mouse-up action toggles it.
      MainActor.assumeIsolated { self?.dismissIfOutside(at: NSEvent.mouseLocation) }
    }
    observe(NSWorkspace.shared.notificationCenter, NSWorkspace.didActivateApplicationNotification)
    observe(NSWorkspace.shared.notificationCenter, NSWorkspace.activeSpaceDidChangeNotification)
    observe(NSWorkspace.shared.notificationCenter, NSWorkspace.screensDidSleepNotification)
    observe(.default, NSApplication.didChangeScreenParametersNotification)
  }

  private func dismissIfOutside(at point: NSPoint) {
    let anchorFrame = anchor.flatMap { button in
      button.window?.convertToScreen(button.convert(button.bounds, to: nil))
    }
    if StatusItemPanelDismissal.shouldClose(at: point, panelFrame: panel.frame, anchorFrame: anchorFrame) {
      close()
    }
  }

  private func observe(_ center: NotificationCenter, _ name: Notification.Name) {
    let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
      if name == NSWorkspace.didActivateApplicationNotification,
         let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
         application.processIdentifier == ProcessInfo.processInfo.processIdentifier {
        return
      }
      MainActor.assumeIsolated { self?.close() }
    }
    observers.append((center, token))
  }

  private func removeDismissalHandlers() {
    if let localMouseMonitor { NSEvent.removeMonitor(localMouseMonitor) }
    if let globalMouseMonitor { NSEvent.removeMonitor(globalMouseMonitor) }
    localMouseMonitor = nil
    globalMouseMonitor = nil
    for (center, token) in observers { center.removeObserver(token) }
    observers.removeAll()
  }
}

@MainActor
private final class MenuBarPanel: NSPanel {
  var onDismiss: (() -> Void)?
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }
  override func cancelOperation(_ sender: Any?) { onDismiss?() }

  override func sendEvent(_ event: NSEvent) {
    if event.type == .keyDown, event.keyCode == 53 {
      onDismiss?()
      return
    }
    super.sendEvent(event)
  }
}
