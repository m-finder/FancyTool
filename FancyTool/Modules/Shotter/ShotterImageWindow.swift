//
//  ShotterImageWindow.swift
//  FancyTool
//

import AppKit
import UniformTypeIdentifiers

@MainActor
final class ShotterImageWindow: NSWindow, NSWindowDelegate {

  var onClose: (() -> Void)?
  private let editorView: ShotterEditorView
  private let selectionRect: NSRect?
  private let fullScreenCaptureScreen: NSScreen?
  private var toolbarWindow: ShotterToolbarWindow?
  private var isDismissing = false

  init(image: NSImage, sourceCGImage: CGImage? = nil, selectionRect: NSRect?) {
    self.selectionRect = selectionRect
    fullScreenCaptureScreen = selectionRect.flatMap(Self.fullScreenCaptureScreen(for:))
    editorView = ShotterEditorView(
      image: image,
      sourceCGImage: sourceCGImage,
      fillsScreen: fullScreenCaptureScreen != nil
    )

    let imageSize = image.size
    let screen = fullScreenCaptureScreen ?? selectionRect.flatMap { ShotterCoordinateSpace.screen(for: $0) } ?? NSScreen.main
    let availableFrame = fullScreenCaptureScreen?.frame
      ?? screen?.frame
      ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    let maximumImageSize = CGSize(
      width: max(1, availableFrame.width),
      height: max(1, availableFrame.height)
    )
    let scale = min(
      1,
      min(
        maximumImageSize.width / max(imageSize.width, 1),
        maximumImageSize.height / max(imageSize.height, 1)
      )
    )
    let imageDisplaySize = CGSize(
      width: imageSize.width * scale,
      height: imageSize.height * scale
    )
    let contentSize = fullScreenCaptureScreen?.frame.size ?? imageDisplaySize

    super.init(
      contentRect: NSRect(origin: .zero, size: contentSize),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )

    delegate = self
    // NSWindow's legacy release-on-close semantics conflict with ARC-held
    // Swift references and AppKit's deferred display/Touch Bar cleanup.
    isReleasedWhenClosed = false
    isOpaque = false
    backgroundColor = .clear
    hasShadow = fullScreenCaptureScreen == nil
    animationBehavior = .none
    level = .screenSaver
    isMovableByWindowBackground = false
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    contentView = editorView
    editorView.hostWindow = self
    toolbarWindow = ShotterToolbarWindow(editor: editorView)
  }

  var isFullScreenCapture: Bool { fullScreenCaptureScreen != nil }

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }

  override func cancelOperation(_ sender: Any?) {
    dismissWindow()
  }

  override func sendEvent(_ event: NSEvent) {
    if event.type == .keyDown, event.keyCode == 53, editorView.handleShortcut(event) { return }
    super.sendEvent(event)
  }

  override func keyDown(with event: NSEvent) {
    if event.keyCode == 53 {
      dismissWindow()
      return
    }
    super.keyDown(with: event)
  }

  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    if editorView.handleShortcut(event) { return true }
    if event.type == .keyDown, event.keyCode == 53 {
      dismissWindow()
      return true
    }
    return super.performKeyEquivalent(with: event)
  }

  func show() {
    positionNearSelection()
    orderFrontRegardless()
    makeKey()
    makeFirstResponder(editorView)
    showToolbar()
  }

  private func showToolbar() {
    guard let toolbarWindow else { return }
    if toolbarWindow.parent !== self {
      addChildWindow(toolbarWindow, ordered: .above)
    }
    toolbarWindow.level = level
    updateToolbarPosition()
    toolbarWindow.orderFrontRegardless()
  }

  fileprivate func synchronizeToolbarLevel() {
    toolbarWindow?.level = level
  }

  private func updateToolbarPosition() {
    guard let toolbarWindow,
          let screen = self.screen ?? selectionRect.flatMap({ ShotterCoordinateSpace.screen(for: $0) }) ?? NSScreen.main else {
      return
    }

    let imageRectInWindow = editorView.convert(editorView.currentImageRect, to: nil)
    let imageRect = convertToScreen(imageRectInWindow)
    let availableFrame = screen.visibleFrame
    let toolbarSize = toolbarWindow.preferredSize
    let horizontalOrigin = min(
      max(imageRect.midX - toolbarSize.width / 2, availableFrame.minX + 8),
      availableFrame.maxX - toolbarSize.width - 8
    )
    let belowOriginY = imageRect.minY - toolbarSize.height - 10
    let fitsBelowImage = belowOriginY >= availableFrame.minY + 8
    let verticalOrigin: CGFloat
    if fitsBelowImage {
      verticalOrigin = belowOriginY
    } else if imageRect.maxY + 10 + toolbarSize.height <= availableFrame.maxY - 8 {
      verticalOrigin = imageRect.maxY + 10
    } else {
      verticalOrigin = min(
        max(imageRect.minY + 12, availableFrame.minY + 8),
        availableFrame.maxY - toolbarSize.height - 8
      )
    }

    toolbarWindow.setFrame(
      NSRect(origin: NSPoint(x: horizontalOrigin, y: verticalOrigin), size: toolbarSize),
      display: true
    )
  }

  private func positionNearSelection() {
    if let fullScreenCaptureScreen {
      setFrame(fullScreenCaptureScreen.frame, display: true)
      return
    }

    guard let selectionRect else {
      center()
      return
    }

    let screen = ShotterCoordinateSpace.screen(for: selectionRect) ?? NSScreen.main
    guard let availableFrame = screen?.frame else {
      center()
      return
    }

    let imageRect = editorView.currentImageRect
    let imageOffset = NSPoint(x: imageRect.minX, y: imageRect.minY)
    // The preview image should stay aligned with the captured region. Do not
    // reserve space by moving the preview upward for the floating toolbar:
    // updateToolbarPosition() will place the toolbar inside the image whenever
    // there is not enough room below it.
    let minimumOriginX = availableFrame.minX - imageRect.minX
    let minimumOriginY = availableFrame.minY - imageRect.minY
    let maximumOriginX = max(minimumOriginX, availableFrame.maxX - imageRect.maxX)
    let maximumOriginY = max(minimumOriginY, availableFrame.maxY - imageRect.maxY)
    let origin = NSPoint(
      x: min(max(selectionRect.minX - imageOffset.x, minimumOriginX), maximumOriginX),
      y: min(max(selectionRect.minY - imageOffset.y, minimumOriginY), maximumOriginY)
    )
    setFrameOrigin(origin)
  }

  private static func fullScreenCaptureScreen(for selectionRect: NSRect) -> NSScreen? {
    // A selection made through the overlay can differ from NSScreen.frame by a
    // fractional point on a secondary display. Prefer the display containing
    // the selection centre and treat it as full-screen only when virtually all
    // of that display is selected; this avoids both false positives for
    // cross-display selections and secondary-display preview shrinking.
    let center = NSPoint(x: selectionRect.midX, y: selectionRect.midY)
    let orderedScreens = NSScreen.screens.sorted { lhs, rhs in
      let lhsContainsCenter = lhs.frame.contains(center)
      let rhsContainsCenter = rhs.frame.contains(center)
      if lhsContainsCenter != rhsContainsCenter {
        return lhsContainsCenter
      }

      let lhsCoverage = coverage(of: lhs.frame, by: selectionRect)
      let rhsCoverage = coverage(of: rhs.frame, by: selectionRect)
      return lhsCoverage > rhsCoverage
    }

    return orderedScreens.first { screen in
      coverage(of: screen.frame, by: selectionRect) >= 0.98
    }
  }

  private static func coverage(of frame: NSRect, by selectionRect: NSRect) -> CGFloat {
    guard frame.width > 0, frame.height > 0 else { return 0 }
    let intersection = frame.intersection(selectionRect)
    guard !intersection.isNull, !intersection.isEmpty else { return 0 }
    return (intersection.width * intersection.height) / (frame.width * frame.height)
  }

  func dismissWindow() {
    guard !isDismissing else { return }
    isDismissing = true

    dismissToolbarWindow()
    close()
  }

  private func dismissToolbarWindow() {
    guard let toolbarWindow else { return }
    self.toolbarWindow = nil

    if toolbarWindow.parent === self {
      removeChildWindow(toolbarWindow)
    }
    toolbarWindow.orderOut(nil)
    toolbarWindow.close()
  }

  func windowDidMove(_ notification: Notification) {
    updateToolbarPosition()
  }

  func windowDidResize(_ notification: Notification) {
    updateToolbarPosition()
  }

  func windowDidChangeScreen(_ notification: Notification) {
    updateToolbarPosition()
  }

  func windowWillClose(_ notification: Notification) {
    dismissToolbarWindow()
    onClose?()
    onClose = nil
  }
}

@MainActor
private final class ShotterToolbarWindow: NSPanel {

  private let toolbarContainer: ShotterToolbarContainerView
  private weak var editor: ShotterEditorView?

  var preferredSize: NSSize {
    toolbarContainer.preferredSize
  }

  init(editor: ShotterEditorView) {
    self.editor = editor
    toolbarContainer = ShotterToolbarContainerView(editor: editor)
    super.init(
      contentRect: NSRect(origin: .zero, size: toolbarContainer.preferredSize),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )

    isReleasedWhenClosed = false
    isOpaque = false
    backgroundColor = .clear
    hasShadow = true
    animationBehavior = .none
    level = .floating
    collectionBehavior = [.fullScreenAuxiliary, .stationary, .ignoresCycle]
    hidesOnDeactivate = false
    isMovable = false
    contentView = toolbarContainer
  }

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }

  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    if editor?.handleShortcut(event) == true { return true }
    return super.performKeyEquivalent(with: event)
  }

  override func sendEvent(_ event: NSEvent) {
    if event.type == .keyDown, editor?.handleShortcut(event) == true { return }
    super.sendEvent(event)
  }
}

@MainActor
private final class ShotterToolbarContainerView: NSView {

  private weak var editor: ShotterEditorView?

  var preferredSize: NSSize {
    editor?.toolbarPreferredSize ?? ShotterToolbarView.preferredSize
  }

  init(editor: ShotterEditorView) {
    self.editor = editor
    super.init(frame: NSRect(origin: .zero, size: editor.toolbarPreferredSize))
    wantsLayer = true
    editor.installToolbar(in: self)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layout() {
    super.layout()
    editor?.layoutToolbar(in: bounds)
  }
}

@MainActor
final class ShotterEditorView: NSView {
  typealias Tool = ShotterTool
  typealias Annotation = ShotterAnnotation

  weak var hostWindow: ShotterImageWindow?
  private let image: NSImage
  private let sourceCGImage: CGImage?
  private let fillsScreen: Bool
  private var editHistory = ShotterEditHistory<[Annotation]>(initial: [])
  private var annotations: [Annotation] { editHistory.value }
  private var selectedTool: Tool = .none
  private var style = ShotterAnnotationStyle(color: .red, lineWidth: 4, fontSize: 22)
  private var selectedIndex: Int?
  private var draft: Annotation?
  private var dragOrigin: NSPoint?
  private var originalAnnotation: Annotation?
  private var movedAnnotation: Annotation?
  private var isPinned = false
  private var toolbar: ShotterToolbarView!
  private var activeSavePanel: NSSavePanel?
  private var textField: NSTextField?
  private var textEntryPoint: NSPoint?
  private var editingTextIndex: Int?

  init(image: NSImage, sourceCGImage: CGImage? = nil, fillsScreen: Bool) {
    self.image = image
    self.sourceCGImage = sourceCGImage
    self.fillsScreen = fillsScreen
    super.init(frame: .zero)
    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor
    setupToolbar()
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
  override var acceptsFirstResponder: Bool { true }
  override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); updateLayerScale() }
  override func viewDidChangeBackingProperties() { super.viewDidChangeBackingProperties(); updateLayerScale() }
  override func resetCursorRects() {
    addCursorRect(bounds, cursor: selectedTool == .none ? .arrow : .crosshair)
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    let rect = imageRect
    guard !rect.isEmpty else { return }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current?.imageInterpolation = .high
    NSBezierPath(rect: rect).addClip()
    image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
    for (index, annotation) in annotations.enumerated() where index != editingTextIndex {
      (index == selectedIndex ? (movedAnnotation ?? annotation) : annotation).draw(in: rect, imageSize: image.size)
    }
    draft?.draw(in: rect, imageSize: image.size)
    if let index = selectedIndex, annotations.indices.contains(index), editingTextIndex == nil {
      let annotation = movedAnnotation ?? annotations[index]
      let selection = viewRect(annotation.bounds, in: rect).insetBy(dx: -4, dy: -4)
      let path = NSBezierPath(roundedRect: selection, xRadius: 4, yRadius: 4)
      path.lineWidth = 1
      path.setLineDash([4, 3], count: 2, phase: 0)
      NSColor.controlAccentColor.setStroke(); path.stroke()
      for point in [NSPoint(x: selection.minX, y: selection.minY), NSPoint(x: selection.maxX, y: selection.minY),
                    NSPoint(x: selection.minX, y: selection.maxY), NSPoint(x: selection.maxX, y: selection.maxY)] {
        NSColor.white.setFill()
        let dot = NSBezierPath(ovalIn: NSRect(x: point.x-2.5, y: point.y-2.5, width: 5, height: 5))
        dot.fill(); NSColor.controlAccentColor.setStroke(); dot.lineWidth = 1; dot.stroke()
      }
    }
    let border = NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5))
    border.lineWidth = 1 / max(window?.backingScaleFactor ?? 2, 1)
    NSColor.labelColor.withAlphaComponent(0.25).setStroke(); border.stroke()
    NSGraphicsContext.restoreGraphicsState()
  }

  private func updateLayerScale() {
    layer?.contentsScale = window?.backingScaleFactor ?? 2
    needsDisplay = true
  }

  override func mouseDown(with event: NSEvent) {
    commitTextEntry()
    window?.makeFirstResponder(self)
    let local = convert(event.locationInWindow, from: nil)
    guard imageRect.contains(local) else { return }
    let point = imagePoint(from: local)
    if selectedTool == .none {
      selectedIndex = annotations.indices.reversed().first { annotations[$0].contains(point, tolerance: 6 / displayScale) }
      if let index = selectedIndex {
        style = annotations[index].style
        if event.clickCount == 2, annotations[index].tool == .text {
          beginTextEntry(at: annotations[index].start, editing: index)
        } else {
          dragOrigin = point
          originalAnnotation = annotations[index]
        }
      } else {
        hostWindow?.performDrag(with: event)
      }
      updateToolbar(); needsDisplay = true
      return
    }
    selectedIndex = nil
    if selectedTool == .text {
      beginTextEntry(at: point)
    } else if selectedTool == .number {
      let next = (annotations.filter { $0.tool == .number }.map(\.number).max() ?? 0) + 1
      append(Annotation(tool: .number, start: point, end: point, number: next, style: style))
    } else {
      draft = Annotation(tool: selectedTool, start: point, end: point, points: [.pen, .highlighter].contains(selectedTool) ? [point] : [], style: style)
    }
    updateToolbar(); needsDisplay = true
  }

  override func mouseDragged(with event: NSEvent) {
    let point = imagePoint(from: convert(event.locationInWindow, from: nil))
    if let origin = dragOrigin, let original = originalAnnotation {
      movedAnnotation = translatedWithinImage(original, by: NSPoint(x: point.x-origin.x, y: point.y-origin.y))
    } else if var annotation = draft {
      var end = point
      if event.modifierFlags.contains(.shift) {
        let dx = end.x-annotation.start.x, dy = end.y-annotation.start.y
        if [.rectangle, .oval].contains(annotation.tool) {
          let length = min(abs(dx), abs(dy))
          end = NSPoint(x: annotation.start.x + (dx < 0 ? -length : length), y: annotation.start.y + (dy < 0 ? -length : length))
        } else if annotation.tool == .arrow {
          let angle = (atan2(dy, dx) / (.pi/4)).rounded() * (.pi/4)
          let length = hypot(dx, dy)
          end = NSPoint(x: annotation.start.x + cos(angle)*length, y: annotation.start.y + sin(angle)*length)
        }
      }
      annotation.end = end
      if [.pen, .highlighter].contains(annotation.tool), let last = annotation.points.last,
         hypot(point.x-last.x, point.y-last.y) >= 0.5 / displayScale {
        annotation.points.append(point)
      }
      draft = annotation
    }
    needsDisplay = true
  }

  override func mouseUp(with event: NSEvent) {
    if let index = selectedIndex, let movedAnnotation {
      var updated = annotations
      updated[index] = movedAnnotation
      editHistory.commit(updated)
    } else if let draft, hypot(draft.end.x-draft.start.x, draft.end.y-draft.start.y) > 2 || draft.points.count > 2 {
      append(draft)
    }
    clearDrag()
    updateToolbar(); needsDisplay = true
  }

  override func keyDown(with event: NSEvent) {
    if !handleShortcut(event) { super.keyDown(with: event) }
  }

  func handleShortcut(_ event: NSEvent) -> Bool {
    guard event.type == .keyDown else { return false }
    if event.keyCode == 53 {
      if textField != nil { cancelTextEntry() }
      else if draft != nil { clearDrag(); needsDisplay = true }
      else { hostWindow?.dismissWindow() }
      return true
    }
    if textField?.currentEditor() != nil { return false }
    let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
    let key = event.charactersIgnoringModifiers?.lowercased()
    if flags.contains(.command), !flags.contains(.option), !flags.contains(.control) {
      switch key {
      case "z": if flags.contains(.shift) { redo() } else { undo() }; return true
      case "c": copyImage(); return true
      case "s": saveImage(); return true
      default: return false
      }
    }
    guard flags.subtracting(.shift).isEmpty else { return false }
    if event.keyCode == 51 || event.keyCode == 117 { deleteSelection(); return true }
    if event.keyCode == 36 || event.keyCode == 76 { copyImage(); return true }
    let tools: [String: Tool] = ["v": .none, "r": .rectangle, "o": .oval, "a": .arrow, "p": .pen, "h": .highlighter, "t": .text, "n": .number, "x": .redact]
    if let key, let tool = tools[key] { select(tool); return true }
    if let index = selectedIndex, annotations.indices.contains(index), (123...126).contains(event.keyCode) {
      let step: CGFloat = flags.contains(.shift) ? 10 : 1
      let delta = NSPoint(x: event.keyCode == 123 ? -step : (event.keyCode == 124 ? step : 0),
                          y: event.keyCode == 125 ? -step : (event.keyCode == 126 ? step : 0))
      var updated = annotations
      updated[index] = translatedWithinImage(updated[index], by: delta)
      editHistory.commit(updated)
      updateToolbar(); needsDisplay = true
      return true
    }
    return false
  }

  private func select(_ tool: Tool) {
    commitTextEntry(); clearDrag()
    selectedTool = selectedTool == tool ? .none : tool
    selectedIndex = nil
    updateToolbar(); needsDisplay = true
    window?.makeFirstResponder(self)
    window?.invalidateCursorRects(for: self)
  }

  private func append(_ annotation: Annotation) {
    editHistory.commit(annotations + [annotation])
    updateToolbar(); needsDisplay = true
  }

  private func undo() {
    commitTextEntry(); clearDrag(); selectedIndex = nil
    editHistory.undo(); updateToolbar(); needsDisplay = true
  }
  private func redo() {
    commitTextEntry(); clearDrag(); selectedIndex = nil
    editHistory.redo(); updateToolbar(); needsDisplay = true
  }
  private func deleteSelection() {
    guard let index = selectedIndex, annotations.indices.contains(index) else { return }
    if textField != nil { cancelTextEntry() }
    var updated = annotations; updated.remove(at: index)
    editHistory.commit(updated); selectedIndex = nil
    updateToolbar(); needsDisplay = true
  }
  private func clearDrag() { draft = nil; dragOrigin = nil; originalAnnotation = nil; movedAnnotation = nil }

  private func translatedWithinImage(_ annotation: Annotation, by delta: NSPoint) -> Annotation {
    var offset = delta
    let box = annotation.bounds
    if box.width <= image.size.width { offset.x = min(max(offset.x, -box.minX), image.size.width-box.maxX) }
    if box.height <= image.size.height { offset.y = min(max(offset.y, -box.minY), image.size.height-box.maxY) }
    return annotation.translated(by: offset)
  }

  private func setupToolbar() {
    toolbar = ShotterToolbarView(frame: NSRect(origin: .zero, size: ShotterToolbarView.preferredSize))
    toolbar.onTool = { [weak self] in self?.select($0) }
    toolbar.onColor = { [weak self] color in self?.changeStyle { $0.color = color } }
    toolbar.onWidth = { [weak self] width in self?.changeStyle { $0.lineWidth = width } }
    toolbar.onFontSize = { [weak self] size in self?.changeStyle { $0.fontSize = size } }
    toolbar.onOpacity = { [weak self] in self?.hostWindow?.alphaValue = $0 }
    toolbar.onAction = { [weak self] action in
      guard let self else { return }
      switch action {
      case .undo: self.undo()
      case .redo: self.redo()
      case .delete: self.deleteSelection()
      case .pin:
        self.commitTextEntry(); self.isPinned.toggle()
        self.hostWindow?.alphaValue = 1
        self.hostWindow?.level = self.isPinned ? .floating : .screenSaver
        self.hostWindow?.synchronizeToolbarLevel()
        self.updateToolbar()
      case .save: self.saveImage()
      case .copy: self.copyImage()
      case .close: self.hostWindow?.dismissWindow()
      }
    }
    updateToolbar()
  }

  private func changeStyle(_ mutation: (inout ShotterAnnotationStyle) -> Void) {
    mutation(&style)
    if let field = textField {
      field.font = .systemFont(ofSize: style.fontSize * displayScale, weight: .medium)
      field.textColor = style.color.nsColor
      field.setFrameSize(NSSize(width: field.frame.width, height: max(28, style.fontSize * displayScale + 12)))
      window?.makeFirstResponder(field)
    } else if let index = selectedIndex, annotations.indices.contains(index) {
      var updated = annotations; updated[index].style = style
      editHistory.commit(updated)
    }
    updateToolbar(); needsDisplay = true
  }

  private func updateToolbar() {
    let size = sourceCGImage.map { NSSize(width: $0.width, height: $0.height) } ?? image.representations.first.map { NSSize(width: $0.pixelsWide, height: $0.pixelsHigh) } ?? image.size
    let selectionTool = selectedIndex.flatMap { annotations.indices.contains($0) ? annotations[$0].tool : nil }
    toolbar?.update(tool: selectedTool, selectionTool: selectionTool, style: style, canUndo: editHistory.canUndo, canRedo: editHistory.canRedo,
                    hasSelection: selectedIndex != nil, isPinned: isPinned, pixelSize: size)
  }
  var toolbarPreferredSize: NSSize { ShotterToolbarView.preferredSize }
  func installToolbar(in container: NSView) {
    toolbar.removeFromSuperview(); container.addSubview(toolbar)
    toolbar.frame = container.bounds; toolbar.autoresizingMask = [.width, .height]
  }
  func layoutToolbar(in bounds: NSRect) { toolbar.frame = bounds }

  private func beginTextEntry(at point: NSPoint, editing index: Int? = nil) {
    let view = viewPoint(point)
    let fontSize = style.fontSize * displayScale
    let field = NSTextField(frame: NSRect(x: view.x, y: view.y-4, width: max(36, min(280, imageRect.maxX-view.x)), height: max(28, fontSize+12)))
    field.font = .systemFont(ofSize: fontSize, weight: .medium)
    field.textColor = style.color.nsColor
    field.backgroundColor = .textBackgroundColor
    field.placeholderString = String(localized: "Type a label…")
    field.focusRingType = .none
    field.target = self; field.action = #selector(commitTextEntry)
    if let index { field.stringValue = annotations[index].text ?? "" }
    addSubview(field)
    textField = field; textEntryPoint = point; editingTextIndex = index
    window?.makeFirstResponder(field)
    needsDisplay = true
  }

  @objc private func commitTextEntry() {
    guard let field = textField, let point = textEntryPoint else { return }
    let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    let index = editingTextIndex
    field.removeFromSuperview(); textField = nil; textEntryPoint = nil; editingTextIndex = nil
    if !text.isEmpty {
      let annotation = Annotation(tool: .text, start: point, end: point, text: text, style: style)
      if let index, annotations.indices.contains(index) {
        var updated = annotations; updated[index] = annotation; editHistory.commit(updated)
      } else { append(annotation) }
    }
    window?.makeFirstResponder(self)
    updateToolbar(); needsDisplay = true
  }
  private func cancelTextEntry() {
    textField?.removeFromSuperview(); textField = nil; textEntryPoint = nil; editingTextIndex = nil
    window?.makeFirstResponder(self); needsDisplay = true
  }

  private var imageRect: NSRect {
    guard image.size.width > 0, image.size.height > 0 else { return .zero }
    if fillsScreen { return bounds }
    let factor = min(bounds.width/image.size.width, bounds.height/image.size.height)
    let size = NSSize(width: image.size.width*factor, height: image.size.height*factor)
    return NSRect(x: bounds.midX-size.width/2, y: bounds.midY-size.height/2, width: size.width, height: size.height)
  }
  var currentImageRect: NSRect { layoutSubtreeIfNeeded(); return imageRect }
  private var displayScale: CGFloat { max(imageRect.width / max(image.size.width, 1), 0.01) }
  private func imagePoint(from point: NSPoint) -> NSPoint {
    NSPoint(x: min(image.size.width, max(0, (point.x-imageRect.minX)/displayScale)),
            y: min(image.size.height, max(0, (point.y-imageRect.minY)/displayScale)))
  }
  private func viewPoint(_ point: NSPoint) -> NSPoint {
    NSPoint(x: imageRect.minX + point.x*displayScale, y: imageRect.minY + point.y*displayScale)
  }
  private func viewRect(_ rect: NSRect, in target: NSRect) -> NSRect {
    NSRect(x: target.minX + rect.minX*displayScale, y: target.minY + rect.minY*displayScale,
           width: rect.width*displayScale, height: rect.height*displayScale)
  }

  private func saveImage() {
    commitTextEntry()
    let panel = NSSavePanel()
    activeSavePanel = panel
    let level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
    panel.level = level; panel.animationBehavior = .none
    panel.allowedContentTypes = [.png]
    panel.nameFieldStringValue = "FancyTool-\(Int(Date().timeIntervalSince1970)).png"
    panel.canCreateDirectories = true
    DispatchQueue.main.async { [weak panel] in
      panel?.level = level; panel?.makeKeyAndOrderFront(nil); panel?.orderFrontRegardless()
    }
    guard panel.runModal() == .OK, let url = panel.url else { releaseSavePanel(); return }
    guard let data = pngData() else {
      releaseSavePanel(); showSaveError(String(localized: "Unable to create PNG data.")); return
    }
    do {
      try data.write(to: url, options: .atomic)
      DispatchQueue.main.asyncAfter(deadline: .now()+0.15) { [weak self] in
        self?.activeSavePanel = nil; self?.hostWindow?.dismissWindow()
      }
    } catch { releaseSavePanel(); showSaveError(error.localizedDescription) }
  }
  private func releaseSavePanel() { DispatchQueue.main.async { [weak self] in self?.activeSavePanel = nil } }
  private func showSaveError(_ message: String) {
    let alert = NSAlert(); alert.alertStyle = .warning
    alert.messageText = String(localized: "Could not save image"); alert.informativeText = message
    alert.window.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue+1)
    alert.runModal()
  }
  private func copyImage() {
    commitTextEntry()
    guard let data = pngData() else { return }
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    guard pasteboard.setData(data, forType: .png) else { return }
    InteractionFeedback.events.send(.screenshotCopied)
    hostWindow?.dismissWindow()
  }

  func pngData() -> Data? {
    var proposedRect = NSRect(origin: .zero, size: image.size)
    guard let source = sourceCGImage ?? image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil),
          let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: source.width, pixelsHigh: source.height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bitmapFormat: [], bytesPerRow: 0, bitsPerPixel: 0),
          let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
    let rect = NSRect(x: 0, y: 0, width: source.width, height: source.height)
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
    context.imageInterpolation = .none
    NSImage(cgImage: source, size: rect.size).draw(in: rect, from: .zero, operation: .copy, fraction: 1)
    annotations.forEach { $0.draw(in: rect, imageSize: image.size) }
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])
  }
}
