import AppKit
import ApplicationServices
import CoreGraphics

@MainActor
final class ShotterSelectionController {

  var onComplete: ((ShotterCaptureSelection) -> Void)?
  var onCancel: (() -> Void)?

  private var overlayWindows: [ShotterSelectionWindow] = []
  private var candidate: WindowCandidate?
  private var drag: ShotterSelectionGeometry.Drag?
  private var dragRect: NSRect?
  private var isMovingSelection = false
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
    drag = nil
    dragRect = nil
    isMovingSelection = false
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
    selectionCursor.set()
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
    drag = ShotterSelectionGeometry.Drag(at: point)
    dragRect = nil
    isMovingSelection = false
    mousePoint = point
    // Resolve an actual CGWindowID only for a potential click-to-capture.
    // Hovering uses Accessibility first and avoids repeatedly enumerating all
    // windows on every mouse movement.
    candidate = captureCandidate(at: point)
    redraw()
  }

  func handleMouseDragged(to point: NSPoint) {
    guard var drag, !isFinishing else { return }
    mousePoint = point
    drag.update(to: point, square: NSEvent.modifierFlags.contains(.shift), moving: isMovingSelection)
    self.drag = drag
    let rect = drag.rect
    // Once dragging has replaced the hovered window, keep the preview in
    // sync even when the pointer returns to a tiny or empty selection.
    if dragRect != nil || rect.width > 4 || rect.height > 4 {
      candidate = nil
      dragRect = rect
    }
    selectionCursor.set()
    redraw()
  }

  func handleMouseUp(at point: NSPoint) {
    guard drag != nil, !isFinishing else { return }
    handleMouseDragged(to: point)
    guard let rect = drag?.rect else { return }
    let selection: ShotterCaptureSelection?

    if rect.width > 4 && rect.height > 4 {
      selection = ShotterCaptureSelection(rect: rect, windowID: nil)
    } else if let candidate {
      selection = ShotterCaptureSelection(rect: candidate.rect, windowID: candidate.id)
    } else {
      selection = nil
    }

    guard let selection else {
      drag = nil
      dragRect = nil
      isMovingSelection = false
      refreshWindowCandidate(at: point, immediately: true)
      redraw()
      return
    }
    finish(with: selection)
  }

  func handleMouseMoved(to point: NSPoint) {
    guard drag == nil, !isFinishing, mousePoint != point else { return }
    let previousPoint = mousePoint
    mousePoint = point
    selectionCursor.set()
    // Only the old/new pointer displays need their hint and size badge redrawn.
    // A changed window candidate separately invalidates its selection outline.
    for window in overlayWindows where window.frame.contains(point)
      || previousPoint.map({ window.frame.contains($0) }) == true {
      window.contentView?.needsDisplay = true
    }
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
      // Draw the full global outline, letting each view clip it. A selection
      // spanning displays must not acquire false corners at a display seam.
      return NSRect(
        x: rect.minX - frame.minX,
        y: rect.minY - frame.minY,
        width: rect.width,
        height: rect.height
      )
    }
  }

  func cursorPoint(for view: NSView) -> NSPoint? {
    guard let mousePoint, let frame = view.window?.frame else { return nil }
    return NSPoint(x: mousePoint.x - frame.minX, y: mousePoint.y - frame.minY)
  }

  var selectionCursor: NSCursor {
    isMovingSelection ? .closedHand : .crosshair
  }

  var selectionHint: String {
    if isMovingSelection { return String(localized: "Move selection · Release Space to resize") }
    if dragRect != nil { return String(localized: "Release to capture") }
    if candidate != nil { return String(localized: "Click window or drag a region") }
    return String(localized: "Drag to select a region")
  }

  var selectedPixelSize: CGSize? {
    guard let rect = dragRect ?? candidate?.rect, !rect.isEmpty else { return nil }
    let screens: [NSScreen]
    if dragRect == nil, let screen = ShotterCoordinateSpace.screen(for: rect) {
      // A single-window capture follows its host display's native scale.
      screens = [screen]
    } else {
      screens = NSScreen.screens
    }
    return ShotterSelectionGeometry.pixelSize(for: rect, screens: screens.map {
      .init(frame: $0.frame, scale: $0.backingScaleFactor)
    })
  }

  @discardableResult
  func handleKeyDown(_ event: NSEvent) -> Bool {
    guard !isFinishing else { return false }
    switch event.keyCode {
    case 53:
      cancel()
      return true
    case 36, 76:
      guard let screen = ShotterCoordinateSpace.screen(containing: NSEvent.mouseLocation) else { return true }
      finish(with: ShotterCaptureSelection(rect: screen.frame, windowID: nil))
      return true
    case 49:
      if dragRect != nil, !isMovingSelection {
        handleMouseDragged(to: NSEvent.mouseLocation)
        isMovingSelection = true
        selectionCursor.set()
        redraw()
      }
      return true
    default:
      return false
    }
  }

  private func handleSpaceReleased() {
    guard isMovingSelection else { return }
    handleMouseDragged(to: NSEvent.mouseLocation)
    isMovingSelection = false
    selectionCursor.set()
    redraw()
  }

  private func installInputMonitoring() {
    eventMonitor = NSEvent.addLocalMonitorForEvents(
      matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp, .mouseMoved, .keyDown, .keyUp, .flagsChanged]
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
      case .keyDown where self.handleKeyDown(event):
        return nil
      case .keyUp where event.keyCode == 49:
        self.handleSpaceReleased()
        return nil
      case .flagsChanged:
        if self.drag != nil { self.handleMouseDragged(to: NSEvent.mouseLocation) }
        return event
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
        if self.drag == nil {
          self.handleMouseMoved(to: point)
        } else {
          self.handleMouseDragged(to: point)
        }
      }
    }
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
    guard drag == nil, !isFinishing else { return }

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
      guard let self, !self.isFinishing, self.drag == nil, let point = self.mousePoint else { return }
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

    // Our accessibility hit may be the selection overlay. Resolve our own
    // windows through the window-list fallback, which excludes only overlays.
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
    // The window list is ordered front to back. Metadata must not promote a
    // covered window over the visible window under the pointer.
    guard let entry = entries.first(where: { $0.quartzRect.contains(quartzPoint) }) else { return nil }
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

    let overlayWindowIDs = Set(overlayWindows.map { CGWindowID($0.windowNumber) })
    cachedWindowEntries = infos.compactMap { info in
      guard let layer = info[kCGWindowLayer as String] as? Int,
            layer == 0,
            let bounds = info[kCGWindowBounds as String] as? NSDictionary,
            let quartzRect = CGRect(dictionaryRepresentation: bounds),
            isUsableWindowListRect(quartzRect),
            let windowID = info[kCGWindowNumber as String] as? CGWindowID,
            !overlayWindowIDs.contains(windowID) else {
        return nil
      }
      let alpha = info[kCGWindowAlpha as String] as? CGFloat ?? 1
      guard alpha > 0.01 else { return nil }

      return WindowListEntry(id: windowID, quartzRect: quartzRect)
    }
    windowCacheUptime = now
    return cachedWindowEntries
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
    addCursorRect(bounds, cursor: controller?.selectionCursor ?? .crosshair)
  }

  override func draw(_ dirtyRect: NSRect) {
    NSColor.black.withAlphaComponent(0.20).setFill()
    bounds.fill()

    controller?.selectionRects(for: self).forEach { rect in
      NSColor.clear.setFill()
      rect.fill(using: .copy)
      drawSelectionOutline(rect)
    }

    if let point = controller?.cursorPoint(for: self), bounds.contains(point) {
      let hintFrame = drawHints()
      if let size = controller?.selectedPixelSize {
        drawSizeBadge(size, near: point, avoiding: hintFrame)
      }
    }
  }

  private func drawSelectionOutline(_ rect: NSRect) {
    let outline = NSBezierPath(rect: rect)
    NSColor.black.withAlphaComponent(0.32).setStroke()
    outline.lineWidth = 3
    outline.stroke()
    NSColor.controlAccentColor.withAlphaComponent(0.95).setStroke()
    outline.lineWidth = 1
    outline.stroke()

    let length = min(13, min(rect.width, rect.height) / 3)
    guard length > 1 else { return }
    let path = NSBezierPath()
    for (x, directionX) in [(rect.minX, CGFloat(1)), (rect.maxX, CGFloat(-1))] {
      for (y, directionY) in [(rect.minY, CGFloat(1)), (rect.maxY, CGFloat(-1))] {
        path.move(to: NSPoint(x: x + length * directionX, y: y))
        path.line(to: NSPoint(x: x, y: y))
        path.line(to: NSPoint(x: x, y: y + length * directionY))
      }
    }
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.lineWidth = 2
    NSColor.white.setStroke()
    path.stroke()
  }

  @discardableResult
  private func drawHints() -> NSRect {
    let title = controller?.selectionHint ?? String(localized: "Drag to select a region")
    let titleAttributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 11, weight: .medium),
      .foregroundColor: NSColor.white
    ]
    let labelAttributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 10),
      .foregroundColor: NSColor.white.withAlphaComponent(0.78)
    ]
    let keyAttributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .medium),
      .foregroundColor: NSColor.white
    ]
    let shortcuts = [
      ("⇧", String(localized: "Square")),
      ("Space", String(localized: "Move")),
      ("↩", String(localized: "Capture this screen")),
      ("Esc", String(localized: "Cancel"))
    ]
    let itemSizes = shortcuts.map { key, label -> (CGFloat, CGFloat) in
      (max(18, (key as NSString).size(withAttributes: keyAttributes).width + 10),
       (label as NSString).size(withAttributes: labelAttributes).width)
    }
    let rowWidth = itemSizes.reduce(CGFloat(0)) { $0 + $1.0 + 5 + $1.1 } + 14 * CGFloat(shortcuts.count - 1)
    let titleSize = (title as NSString).size(withAttributes: titleAttributes)
    let width = min(bounds.width - 24, max(rowWidth, titleSize.width) + 28)
    let frame = NSRect(x: bounds.midX - width / 2, y: bounds.minY + 22, width: width, height: 58)
    drawPlate(frame, cornerRadius: 13)
    (title as NSString).draw(at: NSPoint(x: frame.midX - titleSize.width / 2, y: frame.minY + 34), withAttributes: titleAttributes)

    // Keep the shortcut row legible on small displays as well as wide monitors.
    let scale = min(1, (width - 28) / max(1, rowWidth))
    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: frame.midX - rowWidth * scale / 2, yBy: frame.minY + 10)
    transform.scale(by: scale)
    transform.concat()
    var x: CGFloat = 0
    for (index, shortcut) in shortcuts.enumerated() {
      let (keyWidth, labelWidth) = itemSizes[index]
      let keyFrame = NSRect(x: x, y: 0, width: keyWidth, height: 18)
      NSColor.white.withAlphaComponent(0.12).setFill()
      NSBezierPath(roundedRect: keyFrame, xRadius: 4, yRadius: 4).fill()
      let keySize = (shortcut.0 as NSString).size(withAttributes: keyAttributes)
      (shortcut.0 as NSString).draw(at: NSPoint(x: keyFrame.midX - keySize.width / 2, y: 3), withAttributes: keyAttributes)
      (shortcut.1 as NSString).draw(at: NSPoint(x: keyFrame.maxX + 5, y: 3), withAttributes: labelAttributes)
      x += keyWidth + 5 + labelWidth + 14
    }
    NSGraphicsContext.restoreGraphicsState()
    return frame
  }

  private func drawSizeBadge(_ size: CGSize, near point: NSPoint, avoiding hintFrame: NSRect) {
    let text = "\(Int(size.width)) × \(Int(size.height)) px"
    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold),
      .foregroundColor: NSColor.white
    ]
    let textSize = (text as NSString).size(withAttributes: attributes)
    let width = textSize.width + 22
    let height: CGFloat = 27
    var frame = NSRect(x: min(max(bounds.minX + 12, point.x + 16), bounds.maxX - width - 12),
                       y: min(max(bounds.minY + 12, point.y - 42), bounds.maxY - height - 12),
                       width: width, height: height)
    if frame.intersects(hintFrame.insetBy(dx: -6, dy: -6)) {
      frame.origin.y = hintFrame.maxY + 9
    }
    drawPlate(frame, cornerRadius: 8)
    (text as NSString).draw(at: NSPoint(x: frame.minX + 11, y: frame.minY + 7), withAttributes: attributes)
  }

  private func drawPlate(_ frame: NSRect, cornerRadius: CGFloat) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
    shadow.shadowBlurRadius = 14
    shadow.shadowOffset = NSSize(width: 0, height: -3)
    shadow.set()
    NSColor(calibratedWhite: 0.08, alpha: 0.94).setFill()
    let plate = NSBezierPath(roundedRect: frame, xRadius: cornerRadius, yRadius: cornerRadius)
    plate.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSColor.white.withAlphaComponent(0.14).setStroke()
    plate.lineWidth = 0.5
    plate.stroke()
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
    controller?.selectionCursor.set()
    controller?.handleMouseMoved(to: NSEvent.mouseLocation)
  }

  override func mouseEntered(with event: NSEvent) {
    controller?.selectionCursor.set()
    controller?.handleMouseMoved(to: NSEvent.mouseLocation)
  }

  override func keyDown(with event: NSEvent) {
    if controller?.handleKeyDown(event) == true { return }
    super.keyDown(with: event)
  }
}
