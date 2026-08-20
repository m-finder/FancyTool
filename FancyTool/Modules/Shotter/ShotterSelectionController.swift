import AppKit
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

  @discardableResult
  func start() -> Bool {
    guard overlayWindows.isEmpty, !NSScreen.screens.isEmpty else { return false }

    isFinishing = false
    candidate = nil
    dragStart = nil
    dragRect = nil
    mousePoint = nil
    NSApp.activate(ignoringOtherApps: true)

    overlayWindows = NSScreen.screens.map { screen in
      let window = ShotterSelectionWindow(
        contentRect: screen.frame,
        styleMask: .borderless,
        backing: .buffered,
        defer: false,
        screen: screen
      )
      window.isOpaque = false
      window.isReleasedWhenClosed = false
      window.backgroundColor = .clear
      window.hasShadow = false
      window.level = .screenSaver
      window.acceptsMouseMovedEvents = true
      window.ignoresMouseEvents = false
      window.hidesOnDeactivate = false
      window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
      window.contentView = ShotterSelectionView(controller: self)
      window.onCancel = { [weak self] in
        self?.cancel()
      }
      window.orderFrontRegardless()
      return window
    }

    if let keyWindow = overlayWindows.first {
      keyWindow.makeKey()
      keyWindow.makeFirstResponder(keyWindow.contentView)
    }

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
    dragStart = point
    dragRect = nil
    mousePoint = point
    candidate = windowCandidate(at: point)
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
      candidate = windowCandidate(at: point)
      redraw()
      return
    }
    finish(with: selection)
  }

  func handleMouseMoved(to point: NSPoint) {
    guard dragStart == nil, !isFinishing else { return }
    mousePoint = point
    let newCandidate = windowCandidate(at: point)
    if newCandidate?.rect != candidate?.rect {
      candidate = newCandidate
    }
    NSCursor.crosshair.set()
    redraw()
  }

  func selectionRect(for view: NSView) -> NSRect? {
    let rect = dragRect ?? candidate?.rect
    guard let rect, let frame = view.window?.frame else { return nil }
    return NSRect(
      x: rect.minX - frame.minX,
      y: rect.minY - frame.minY,
      width: rect.width,
      height: rect.height
    )
  }

  func cursorPoint(for view: NSView) -> NSPoint? {
    guard let mousePoint, let frame = view.window?.frame else { return nil }
    return NSPoint(x: mousePoint.x - frame.minX, y: mousePoint.y - frame.minY)
  }

  private func selectionRect(from start: NSPoint, to end: NSPoint) -> NSRect {
    NSRect(
      x: min(start.x, end.x),
      y: min(start.y, end.y),
      width: abs(end.x - start.x),
      height: abs(end.y - start.y)
    )
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

  private struct WindowCandidate {
    let id: CGWindowID
    let rect: NSRect
  }

  private func windowCandidate(at point: NSPoint) -> WindowCandidate? {
    guard let infos = CGWindowListCopyWindowInfo(
      [.optionOnScreenOnly, .excludeDesktopElements],
      kCGNullWindowID
    ) as? [[String: Any]] else { return nil }

    for info in infos {
      guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
            let owner = info[kCGWindowOwnerName as String] as? String,
            owner != "FancyTool",
            let bounds = info[kCGWindowBounds as String] as? NSDictionary,
            let quartzRect = CGRect(dictionaryRepresentation: bounds),
            quartzRect.width > 2, quartzRect.height > 2,
            let windowID = info[kCGWindowNumber as String] as? CGWindowID else { continue }

      let rect = ShotterCoordinateSpace.appKitRect(fromQuartz: quartzRect)
      if rect.contains(point) {
        return WindowCandidate(id: windowID, rect: rect)
      }
    }
    return nil
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

  init(controller: ShotterSelectionController) {
    self.controller = controller
    super.init(frame: .zero)
    wantsLayer = true
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override var acceptsFirstResponder: Bool { true }

  override func resetCursorRects() {
    addCursorRect(bounds, cursor: .crosshair)
  }

  override func draw(_ dirtyRect: NSRect) {
    NSColor.black.withAlphaComponent(0.12).setFill()
    bounds.fill()

    if let rect = controller?.selectionRect(for: self) {
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

  override func keyDown(with event: NSEvent) {
    if event.keyCode == 53 {
      controller?.cancel()
      return
    }
    super.keyDown(with: event)
  }
}
