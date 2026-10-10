import AppKit
import ApplicationServices
import CoreGraphics

@MainActor
final class ShotterSelectionController {

  var onComplete: ((ShotterCaptureSelection) -> Void)?
  var onCancel: (() -> Void)?

  private var overlayWindows: [ShotterSelectionWindow] = []
  private var candidate: WindowCandidate?
  private var dragStart: NSPoint?
  private var dragRect: NSRect?
  private var mousePoint: NSPoint?
  private var isFinishing = false
  private var eventMonitor: Any?
  private var globalMouseMonitor: Any?

  private var lastWindowProbeUptime: TimeInterval = 0
  private var pendingWindowProbe: DispatchWorkItem?
  private var cachedWindowEntries: [WindowListEntry] = []
  private var windowCacheUptime: TimeInterval = 0

  private let accessibilityWindowProbeInterval: TimeInterval = 1 / 30
  private let windowListProbeInterval: TimeInterval = 1 / 15
  private let windowListCacheLifetime: TimeInterval = 1 / 12

  @discardableResult
  func start() -> Bool {
    guard overlayWindows.isEmpty, !NSScreen.screens.isEmpty else { return false }

    isFinishing = false
    candidate = nil
    dragStart = nil
    dragRect = nil
    mousePoint = nil
    lastWindowProbeUptime = 0
    cachedWindowEntries = []
    windowCacheUptime = 0
    NSApp.activate(ignoringOtherApps: true)

    overlayWindows = NSScreen.screens.map { screen in
      let window = ShotterSelectionWindow(
        contentRect: screen.frame,
        styleMask: .borderless,
        backing: .buffered,
        defer: false,
        screen: screen
      )
      window.setFrame(screen.frame, display: true)
      window.isOpaque = false
      window.isReleasedWhenClosed = false
      window.backgroundColor = .clear
      window.hasShadow = false
      window.level = .screenSaver
      window.acceptsMouseMovedEvents = true
      window.ignoresMouseEvents = false
      window.hidesOnDeactivate = false
      window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
      window.contentView = ShotterSelectionView(frame: NSRect(origin: .zero, size: screen.frame.size), controller: self)
      window.onCancel = { [weak self] in
        self?.cancel()
      }
      window.orderFrontRegardless()
      return window
    }

    installInputMonitoring()
    makeOverlayKey(at: NSEvent.mouseLocation)
    NSCursor.crosshair.set()
    handleMouseMoved(to: NSEvent.mouseLocation)
    return !overlayWindows.isEmpty
  }

  func cancel() {
    guard !isFinishing else { return }
    isFinishing = true
    let cancellation = onCancel
    onCancel = nil
    onComplete = nil
    closeOverlay()
    DispatchQueue.main.async {
      cancellation?()
    }
  }

  func handleMouseDown(at point: NSPoint) {
    guard !isFinishing else { return }
    makeOverlayKey(at: point)
    dragStart = point
    dragRect = nil
    mousePoint = point
    // Resolve an actual CGWindowID only for a potential click-to-capture.
    // Hovering uses Accessibility first and avoids repeatedly enumerating all
    // windows on every mouse movement.
    candidate = captureCandidate(at: point) ?? windowCandidate(at: point)
    redraw()
  }

  func handleMouseDragged(to point: NSPoint) {
    guard let dragStart, !isFinishing else { return }
    mousePoint = point
    let rect = selectionRect(from: dragStart, to: point)
    if rect.width > 4 || rect.height > 4 {
      candidate = nil
      dragRect = rect
    }
    redraw()
  }

  func handleMouseUp(at point: NSPoint) {
    guard let dragStart, !isFinishing else { return }
    mousePoint = point
    let rect = selectionRect(from: dragStart, to: point)
    let selection: ShotterCaptureSelection?

    if rect.width > 4 && rect.height > 4 {
      selection = ShotterCaptureSelection(rect: rect, windowID: nil)
    } else if let candidate {
      selection = ShotterCaptureSelection(rect: candidate.rect, windowID: candidate.id)
    } else {
      selection = nil
    }

    guard let selection else {
      self.dragStart = nil
      dragRect = nil
      refreshWindowCandidate(at: point, immediately: true)
      redraw()
      return
    }
    finish(with: selection)
  }

  func handleMouseMoved(to point: NSPoint) {
    guard dragStart == nil, !isFinishing, mousePoint != point else { return }
    mousePoint = point
    NSCursor.crosshair.set()
    // Keep the crosshair perfectly event-driven. Window lookup is separately
    // coalesced, because CGWindowListCopyWindowInfo is comparatively costly.
    redraw()
    refreshWindowCandidate(at: point)
  }

  func selectionRects(for view: NSView) -> [NSRect] {
    guard let frame = view.window?.frame else { return [] }
    let rects: [NSRect]
    if let dragRect {
      rects = [dragRect]
    } else {
      rects = candidate?.rects ?? []
    }

    return rects.compactMap { rect in
      let portion = rect.intersection(frame)
      guard !portion.isNull, !portion.isEmpty else { return nil }
      return NSRect(
        x: portion.minX - frame.minX,
        y: portion.minY - frame.minY,
        width: portion.width,
        height: portion.height
      )
    }
  }

  func cursorPoint(for view: NSView) -> NSPoint? {
    guard let mousePoint, let frame = view.window?.frame else { return nil }
    return NSPoint(x: mousePoint.x - frame.minX, y: mousePoint.y - frame.minY)
  }

  private func installInputMonitoring() {
    eventMonitor = NSEvent.addLocalMonitorForEvents(
      matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp, .mouseMoved, .keyDown]
    ) { [weak self] event in
      guard let self, !self.isFinishing else { return event }

      switch event.type {
      case .leftMouseDown:
        self.handleMouseDown(at: NSEvent.mouseLocation)
        return nil
      case .leftMouseDragged:
        self.handleMouseDragged(to: NSEvent.mouseLocation)
        return nil
      case .leftMouseUp:
        self.handleMouseUp(at: NSEvent.mouseLocation)
        return nil
      case .mouseMoved:
        self.handleMouseMoved(to: NSEvent.mouseLocation)
        return nil
      case .keyDown where event.keyCode == 53:
        self.cancel()
        return nil
      default:
        return event
      }
    }

    // Mouse-only AppKit monitoring is used solely as an event-driven fallback
    // while a cursor moves between displays. Unlike a CGEvent tap, it does not
    // request the system-wide Input Monitoring permission.
    globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
      matching: [.mouseMoved, .leftMouseDragged]
    ) { [weak self] _ in
      DispatchQueue.main.async { [weak self] in
        guard let self, !self.isFinishing else { return }
        let point = NSEvent.mouseLocation
        if self.dragStart == nil {
          self.handleMouseMoved(to: point)
        } else {
          self.handleMouseDragged(to: point)
        }
      }
    }
  }

  private func selectionRect(from start: NSPoint, to end: NSPoint) -> NSRect {
    NSRect(
      x: min(start.x, end.x),
      y: min(start.y, end.y),
      width: abs(end.x - start.x),
      height: abs(end.y - start.y)
    ).integral
  }

  private func finish(with selection: ShotterCaptureSelection) {
    isFinishing = true
    let completion = onComplete
    onComplete = nil
    onCancel = nil
    closeOverlay()
    DispatchQueue.main.async {
      completion?(selection)
    }
  }

  private func closeOverlay() {
    if let eventMonitor {
      NSEvent.removeMonitor(eventMonitor)
      self.eventMonitor = nil
    }
    if let globalMouseMonitor {
      NSEvent.removeMonitor(globalMouseMonitor)
      self.globalMouseMonitor = nil
    }
    pendingWindowProbe?.cancel()
    pendingWindowProbe = nil
    let windows = overlayWindows
    overlayWindows.removeAll()
    windows.forEach { $0.orderOut(nil) }
    DispatchQueue.main.async {
      windows.forEach { $0.close() }
    }
    NSCursor.arrow.set()
  }


  private func redraw() {
    overlayWindows.forEach { $0.contentView?.needsDisplay = true }
  }

  private func makeOverlayKey(at point: NSPoint) {
    guard let window = overlayWindows.first(where: { NSMouseInRect(point, $0.frame, false) }) else { return }
    if window.isKeyWindow { return }
    window.makeKey()
    window.makeFirstResponder(window.contentView)
  }

  private func refreshWindowCandidate(at point: NSPoint, immediately: Bool = false) {
    guard dragStart == nil, !isFinishing else { return }

    let now = ProcessInfo.processInfo.systemUptime
    let interval = AXIsProcessTrusted() ? accessibilityWindowProbeInterval : windowListProbeInterval
    let elapsed = now - lastWindowProbeUptime
    if immediately || elapsed >= interval {
      pendingWindowProbe?.cancel()
      pendingWindowProbe = nil
      lastWindowProbeUptime = now
      updateWindowCandidate(at: point)
      return
    }

    guard pendingWindowProbe == nil else { return }
    let delay = max(0, interval - elapsed)
    let work = DispatchWorkItem { [weak self] in
      guard let self, !self.isFinishing, self.dragStart == nil, let point = self.mousePoint else { return }
      self.pendingWindowProbe = nil
      self.refreshWindowCandidate(at: point, immediately: true)
    }
    pendingWindowProbe = work
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
  }

  private func updateWindowCandidate(at point: NSPoint) {
    let newCandidate = windowCandidate(at: point)
    if newCandidate?.id != candidate?.id || newCandidate?.rect != candidate?.rect {
      candidate = newCandidate
      redraw()
    }
  }

  private struct WindowCandidate {
    let id: CGWindowID?
    let rect: NSRect
    let rects: [NSRect]
  }

  private struct WindowListEntry {
    let id: CGWindowID
    let quartzRect: CGRect
    let layer: Int
    let ownerPID: Int
    let ownerName: String?
    let title: String?
    let order: Int
  }

  private func windowCandidate(at point: NSPoint) -> WindowCandidate? {
    let quartzPoint = ShotterCoordinateSpace.quartzPoint(fromAppKit: point)
    if let accessibilityCandidate = accessibilityWindowCandidate(at: quartzPoint) {
      return accessibilityCandidate
    }
    return windowListCandidate(at: quartzPoint)
  }

  private func captureCandidate(at point: NSPoint) -> WindowCandidate? {
    // CGWindowList provides the window ID needed for a high-quality single
    // window capture. It is only queried on a click, not continuously.
    let quartzPoint = ShotterCoordinateSpace.quartzPoint(fromAppKit: point)
    return windowListCandidate(at: quartzPoint, refreshCache: true) ?? accessibilityWindowCandidate(at: quartzPoint)
  }

  private func accessibilityWindowCandidate(at quartzPoint: CGPoint) -> WindowCandidate? {
    guard AXIsProcessTrusted() else { return nil }

    let systemWide = AXUIElementCreateSystemWide()
    var element: AXUIElement?
    guard AXUIElementCopyElementAtPosition(systemWide, Float(quartzPoint.x), Float(quartzPoint.y), &element) == .success,
          let element,
          let window = accessibilityWindow(for: element),
          !isOwnAccessibilityElement(window),
          let quartzRect = accessibilityFrame(for: window),
          quartzRect.width > 2,
          quartzRect.height > 2,
          !isScreenSizedQuartzRect(quartzRect) else {
      return nil
    }

    let rects = ShotterCoordinateSpace.appKitRects(fromQuartz: quartzRect)
    return WindowCandidate(
      id: nil,
      rect: ShotterCoordinateSpace.boundingAppKitRect(fromQuartz: quartzRect),
      rects: rects
    )
  }

  private func accessibilityWindow(for element: AXUIElement) -> AXUIElement? {
    var current: AXUIElement? = element
    for _ in 0..<8 {
      guard let currentElement = current else { return nil }
      if accessibilityStringAttribute(kAXRoleAttribute, from: currentElement) == (kAXWindowRole as String) {
        return currentElement
      }
      if let window = accessibilityElementAttribute(kAXWindowAttribute, from: currentElement) {
        return window
      }
      current = accessibilityElementAttribute(kAXParentAttribute, from: currentElement)
    }
    return nil
  }

  private func isOwnAccessibilityElement(_ element: AXUIElement) -> Bool {
    var pid = pid_t(0)
    guard AXUIElementGetPid(element, &pid) == .success else { return false }
    return pid == ProcessInfo.processInfo.processIdentifier
  }

  private func accessibilityFrame(for element: AXUIElement) -> CGRect? {
    guard let position = accessibilityPointAttribute(kAXPositionAttribute, from: element),
          let size = accessibilitySizeAttribute(kAXSizeAttribute, from: element) else {
      return nil
    }
    return CGRect(origin: position, size: size)
  }

  private func accessibilityPointAttribute(_ attribute: String, from element: AXUIElement) -> CGPoint? {
    guard let value = accessibilityAXValueAttribute(attribute, from: element), AXValueGetType(value) == .cgPoint else {
      return nil
    }
    var point = CGPoint.zero
    return AXValueGetValue(value, .cgPoint, &point) ? point : nil
  }

  private func accessibilitySizeAttribute(_ attribute: String, from element: AXUIElement) -> CGSize? {
    guard let value = accessibilityAXValueAttribute(attribute, from: element), AXValueGetType(value) == .cgSize else {
      return nil
    }
    var size = CGSize.zero
    return AXValueGetValue(value, .cgSize, &size) ? size : nil
  }

  private func accessibilityAXValueAttribute(_ attribute: String, from element: AXUIElement) -> AXValue? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
          let value,
          CFGetTypeID(value) == AXValueGetTypeID() else {
      return nil
    }
    return unsafeDowncast(value, to: AXValue.self)
  }

  private func accessibilityStringAttribute(_ attribute: String, from element: AXUIElement) -> String? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
    return value as? String
  }

  private func accessibilityElementAttribute(_ attribute: String, from element: AXUIElement) -> AXUIElement? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
          let value,
          CFGetTypeID(value) == AXUIElementGetTypeID() else {
      return nil
    }
    return unsafeDowncast(value, to: AXUIElement.self)
  }

  private func windowListCandidate(at quartzPoint: CGPoint, refreshCache: Bool = false) -> WindowCandidate? {
    let entries = windowEntries(refreshCache: refreshCache)
    guard let entry = entries
      .filter({ $0.quartzRect.contains(quartzPoint) })
      .sorted(by: betterWindowCandidate)
      .first else { return nil }
    let rects = ShotterCoordinateSpace.appKitRects(fromQuartz: entry.quartzRect)
    return WindowCandidate(
      id: entry.id,
      rect: ShotterCoordinateSpace.boundingAppKitRect(fromQuartz: entry.quartzRect),
      rects: rects
    )
  }

  private func windowEntries(refreshCache: Bool) -> [WindowListEntry] {
    let now = ProcessInfo.processInfo.systemUptime
    if !refreshCache, now - windowCacheUptime < windowListCacheLifetime {
      return cachedWindowEntries
    }
    guard let infos = CGWindowListCopyWindowInfo(
      [.optionOnScreenOnly, .excludeDesktopElements],
      kCGNullWindowID
    ) as? [[String: Any]] else {
      return cachedWindowEntries
    }

    let ownProcessID = ProcessInfo.processInfo.processIdentifier
    cachedWindowEntries = infos.enumerated().compactMap { index, info in
      guard let layer = info[kCGWindowLayer as String] as? Int,
            layer == 0,
            let ownerPID = info[kCGWindowOwnerPID as String] as? Int,
            ownerPID != ownProcessID,
            let bounds = info[kCGWindowBounds as String] as? NSDictionary,
            let quartzRect = CGRect(dictionaryRepresentation: bounds),
            isUsableWindowListRect(quartzRect),
            let windowID = info[kCGWindowNumber as String] as? CGWindowID else {
        return nil
      }
      let alpha = info[kCGWindowAlpha as String] as? CGFloat ?? 1
      guard alpha > 0.01 else { return nil }

      return WindowListEntry(
        id: windowID,
        quartzRect: quartzRect,
        layer: layer,
        ownerPID: ownerPID,
        ownerName: info[kCGWindowOwnerName as String] as? String,
        title: info[kCGWindowName as String] as? String,
        order: index
      )
    }
    windowCacheUptime = now
    return cachedWindowEntries
  }

  private func betterWindowCandidate(_ lhs: WindowListEntry, _ rhs: WindowListEntry) -> Bool {
    let lhsScreenSized = isScreenSizedQuartzRect(lhs.quartzRect)
    let rhsScreenSized = isScreenSizedQuartzRect(rhs.quartzRect)
    if lhsScreenSized != rhsScreenSized {
      return !lhsScreenSized
    }

    let lhsHasTitle = lhs.title?.isEmpty == false
    let rhsHasTitle = rhs.title?.isEmpty == false
    if lhsHasTitle != rhsHasTitle {
      return lhsHasTitle
    }

    return lhs.order < rhs.order
  }

  private func isUsableWindowListRect(_ rect: CGRect) -> Bool {
    rect.width > 24 && rect.height > 24
  }

  private func isScreenSizedQuartzRect(_ rect: CGRect) -> Bool {
    NSScreen.screens.contains { screen in
      let screenRect = ShotterCoordinateSpace.quartzRect(fromAppKit: screen.frame)
      let widthDelta = abs(rect.width - screenRect.width)
      let heightDelta = abs(rect.height - screenRect.height)
      return widthDelta <= 2 && heightDelta <= 2 && rect.intersects(screenRect)
    }
  }

}

@MainActor
private final class ShotterSelectionWindow: NSPanel {

  var onCancel: (() -> Void)?

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }

  override func cancelOperation(_ sender: Any?) {
    onCancel?()
  }
}

@MainActor
private final class ShotterSelectionView: NSView {

  private weak var controller: ShotterSelectionController?
  private var trackingArea: NSTrackingArea?

  init(frame: NSRect, controller: ShotterSelectionController) {
    self.controller = controller
    super.init(frame: frame)
    autoresizingMask = [.width, .height]
    wantsLayer = true
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override var acceptsFirstResponder: Bool { true }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()

    if let trackingArea {
      removeTrackingArea(trackingArea)
    }

    let trackingArea = NSTrackingArea(
      rect: bounds,
      options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .cursorUpdate, .inVisibleRect],
      owner: self,
      userInfo: nil
    )
    addTrackingArea(trackingArea)
    self.trackingArea = trackingArea
  }

  override func resetCursorRects() {
    addCursorRect(bounds, cursor: .crosshair)
  }

  override func draw(_ dirtyRect: NSRect) {
    NSColor.black.withAlphaComponent(0.12).setFill()
    bounds.fill()

    controller?.selectionRects(for: self).forEach { rect in
      NSColor.clear.setFill()
      rect.fill(using: .copy)
      NSColor.controlAccentColor.withAlphaComponent(0.95).setStroke()
      let path = NSBezierPath(rect: rect)
      path.lineWidth = 2
      path.stroke()
    }

    if let point = controller?.cursorPoint(for: self), bounds.contains(point) {
      drawCrosshair(at: point)
    }
  }

  private func drawCrosshair(at point: NSPoint) {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: 0, y: point.y))
    path.line(to: NSPoint(x: bounds.width, y: point.y))
    path.move(to: NSPoint(x: point.x, y: 0))
    path.line(to: NSPoint(x: point.x, y: bounds.height))
    NSColor.controlAccentColor.withAlphaComponent(0.72).setStroke()
    path.lineWidth = 1
    path.stroke()
  }

  override func mouseDown(with event: NSEvent) {
    controller?.handleMouseDown(at: NSEvent.mouseLocation)
  }

  override func mouseDragged(with event: NSEvent) {
    controller?.handleMouseDragged(to: NSEvent.mouseLocation)
  }

  override func mouseUp(with event: NSEvent) {
    controller?.handleMouseUp(at: NSEvent.mouseLocation)
  }

  override func mouseMoved(with event: NSEvent) {
    controller?.handleMouseMoved(to: NSEvent.mouseLocation)
  }

  override func cursorUpdate(with event: NSEvent) {
    NSCursor.crosshair.set()
    controller?.handleMouseMoved(to: NSEvent.mouseLocation)
  }

  override func mouseEntered(with event: NSEvent) {
    NSCursor.crosshair.set()
    controller?.handleMouseMoved(to: NSEvent.mouseLocation)
  }

  override func keyDown(with event: NSEvent) {
    if event.keyCode == 53 {
      controller?.cancel()
      return
    }
    super.keyDown(with: event)
  }
}
