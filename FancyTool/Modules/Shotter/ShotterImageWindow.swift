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
  private var isDismissing = false

  init(image: NSImage, selectionRect: NSRect?) {
    editorView = ShotterEditorView(image: image)
    self.selectionRect = selectionRect

    let imageSize = image.size
    let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    let maximumImageSize = CGSize(
      width: min(1000, visibleFrame.width * 0.78),
      height: min(760, max(320, visibleFrame.height * 0.72 - 52))
    )
    let scale = min(
      1,
      min(
        maximumImageSize.width / max(imageSize.width, 1),
        maximumImageSize.height / max(imageSize.height, 1)
      )
    )
    let contentSize = CGSize(
      width: max(340, imageSize.width * scale),
      height: max(250, imageSize.height * scale + 52)
    )

    super.init(
      contentRect: NSRect(origin: .zero, size: contentSize),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )

    delegate = self
    isOpaque = false
    backgroundColor = .clear
    hasShadow = true
    animationBehavior = .none
    level = .normal
    isMovableByWindowBackground = false
    collectionBehavior = [.fullScreenAuxiliary]
    contentView = editorView
    editorView.hostWindow = self
  }

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }

  override func cancelOperation(_ sender: Any?) {
    dismissWindow()
  }

  override func sendEvent(_ event: NSEvent) {
    if event.type == .keyDown, event.keyCode == 53 {
      dismissWindow()
      return
    }
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
  }

  private func positionNearSelection() {
    guard let selectionRect else {
      center()
      return
    }

    let selectionCenter = NSPoint(x: selectionRect.midX, y: selectionRect.midY)
    let screen = NSScreen.screens.first { $0.frame.contains(selectionCenter) }
      ?? NSScreen.main
    guard let visibleFrame = screen?.visibleFrame else {
      center()
      return
    }

    let windowSize = frame.size
    let maximumOriginX = max(visibleFrame.minX, visibleFrame.maxX - windowSize.width)
    let maximumOriginY = max(visibleFrame.minY, visibleFrame.maxY - windowSize.height)
    let origin = NSPoint(
      x: min(max(selectionRect.minX, visibleFrame.minX), maximumOriginX),
      y: min(max(selectionRect.maxY - windowSize.height, visibleFrame.minY), maximumOriginY)
    )
    setFrameOrigin(origin)
  }

  func dismissWindow() {
    guard !isDismissing else { return }
    isDismissing = true

    makeFirstResponder(nil)
    touchBar = nil
    animationBehavior = .none
    orderOut(nil)
    close()
  }

  func windowWillClose(_ notification: Notification) {
    onClose?()
    onClose = nil
  }
}

@MainActor
private final class ShotterEditorView: NSView {

  enum Tool: Hashable {
    case none
    case rectangle
    case oval
    case arrow
    case text
  }

  struct Annotation {
    let tool: Tool
    let start: NSPoint
    let end: NSPoint
    let text: String?

    init(tool: Tool, start: NSPoint, end: NSPoint, text: String? = nil) {
      self.tool = tool
      self.start = start
      self.end = end
      self.text = text
    }
  }

  weak var hostWindow: ShotterImageWindow?

  private let image: NSImage
  private var annotations: [Annotation] = []
  private var selectedTool: Tool = .none
  private var annotationStart: NSPoint?
  private var annotationEnd: NSPoint?
  private var isPinned = false
  private var toolbar: NSStackView!
  private var opacitySlider: NSSlider!
  private var opacityPanel: NSView!
  private var toolButtons: [Tool: NSButton] = [:]
  private var activeSavePanel: NSSavePanel?
  private var textField: NSTextField?
  private var textEntryPoint: NSPoint?
  private var draggedAnnotationIndex: Int?
  private var draggedAnnotationStart: NSPoint?
  private var draggedAnnotation: Annotation?

  init(image: NSImage) {
    self.image = image
    super.init(frame: .zero)
    wantsLayer = true
    layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.94).cgColor
    setupToolbar()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var acceptsFirstResponder: Bool { true }

  override func layout() {
    super.layout()
    toolbar.frame = NSRect(x: 10, y: 8, width: bounds.width - 20, height: 34)
    opacityPanel.frame = NSRect(
      x: max(12, bounds.midX - 60),
      y: toolbar.frame.maxY + 15,
      width: 120,
      height: 16
    )
    opacitySlider.frame = opacityPanel.bounds
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)

    let rect = imageRect
    guard !rect.isEmpty else { return }

    NSColor.black.withAlphaComponent(0.16).setFill()
    NSBezierPath(roundedRect: rect, xRadius: 14, yRadius: 14).fill()

    NSGraphicsContext.current?.saveGraphicsState()
    NSBezierPath(roundedRect: rect, xRadius: 14, yRadius: 14).addClip()
    image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)

    annotations.forEach { draw($0, in: rect) }
    if let start = annotationStart, let end = annotationEnd {
      draw(Annotation(tool: selectedTool, start: start, end: end), in: rect)
    }
    NSGraphicsContext.current?.restoreGraphicsState()
  }

  override func mouseDown(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    guard let imagePoint = imagePoint(from: point) else {
      commitTextEntry()
      hostWindow?.performDrag(with: event)
      return
    }

    if let index = annotationIndex(at: imagePoint) {
      commitTextEntry()
      draggedAnnotationIndex = index
      draggedAnnotationStart = imagePoint
      draggedAnnotation = annotations[index]
      return
    }

    if selectedTool == .text {
      beginTextEntry(at: point, imagePoint: imagePoint)
      return
    }

    guard selectedTool != .none else {
      commitTextEntry()
      hostWindow?.performDrag(with: event)
      return
    }
    annotationStart = imagePoint
    annotationEnd = imagePoint
    needsDisplay = true
  }

  override func mouseDragged(with event: NSEvent) {
    if let index = draggedAnnotationIndex,
       let start = draggedAnnotationStart,
       let annotation = draggedAnnotation,
       let point = imagePoint(from: convert(event.locationInWindow, from: nil)) {
      let offset = NSPoint(x: point.x - start.x, y: point.y - start.y)
      annotations[index] = Annotation(
        tool: annotation.tool,
        start: NSPoint(x: annotation.start.x + offset.x, y: annotation.start.y + offset.y),
        end: NSPoint(x: annotation.end.x + offset.x, y: annotation.end.y + offset.y),
        text: annotation.text
      )
      needsDisplay = true
      return
    }

    guard annotationStart != nil else { return }
    let point = convert(event.locationInWindow, from: nil)
    annotationEnd = imagePoint(from: point)
    needsDisplay = true
  }

  override func mouseUp(with event: NSEvent) {
    if draggedAnnotationIndex != nil {
      draggedAnnotationIndex = nil
      draggedAnnotationStart = nil
      draggedAnnotation = nil
      needsDisplay = true
      return
    }

    guard let start = annotationStart,
          let end = annotationEnd,
          selectedTool != .none else {
      annotationStart = nil
      annotationEnd = nil
      return
    }

    if abs(end.x - start.x) > 2 || abs(end.y - start.y) > 2 {
      annotations.append(Annotation(tool: selectedTool, start: start, end: end))
    }
    annotationStart = nil
    annotationEnd = nil
    needsDisplay = true
  }

  override func keyDown(with event: NSEvent) {
    if event.keyCode == 53 {
      hostWindow?.dismissWindow()
      return
    }
    super.keyDown(with: event)
  }

  private func setupToolbar() {
    let rectangle = makeToolButton(
      symbol: "rectangle",
      tooltip: String(localized: "Rectangle"),
      action: #selector(selectRectangle),
      isToggle: true
    )
    let oval = makeToolButton(
      symbol: "circle",
      tooltip: String(localized: "Circle"),
      action: #selector(selectOval),
      isToggle: true
    )
    let arrow = makeToolButton(
      symbol: "arrow.up.right",
      tooltip: String(localized: "Arrow"),
      action: #selector(selectArrow),
      isToggle: true
    )
    let text = makeToolButton(
      symbol: "text.cursor",
      tooltip: String(localized: "Text"),
      action: #selector(selectText),
      isToggle: true
    )
    let pin = makeToolButton(
      symbol: "pin",
      tooltip: String(localized: "Pin"),
      action: #selector(togglePin)
    )
    pin.tag = 100
    opacitySlider = OpacitySlider(
      value: 1,
      minValue: 0.2,
      maxValue: 1,
      target: self,
      action: #selector(updateOpacity)
    )
    opacitySlider.isContinuous = true
    opacitySlider.controlSize = .small
    opacitySlider.toolTip = String(localized: "Opacity")
    opacityPanel = NSView()
    opacityPanel.isHidden = true
    opacityPanel.addSubview(opacitySlider)
    let download = makeToolButton(
      symbol: "arrow.down.to.line",
      tooltip: String(localized: "Download"),
      action: #selector(downloadImage)
    )
    let close = makeToolButton(
      symbol: "checkmark",
      tooltip: String(localized: "Copy to Clipboard"),
      action: #selector(copyImageToPasteboard)
    )

    toolButtons = [
      .rectangle: rectangle,
      .oval: oval,
      .arrow: arrow,
      .text: text
    ]
    toolbar = NSStackView(views: [rectangle, oval, arrow, text, pin, download, close])
    toolbar.orientation = .horizontal
    toolbar.alignment = .centerY
    toolbar.distribution = .fill
    toolbar.spacing = 6
    addSubview(toolbar)
    addSubview(opacityPanel)
  }

  private func makeToolButton(
    symbol: String,
    tooltip: String,
    action: Selector,
    isToggle: Bool = false,
    title: String? = nil
  ) -> NSButton {
    let button = NSButton(
      image: NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip) ?? NSImage(),
      target: self,
      action: action
    )
    button.bezelStyle = .regularSquare
    if isToggle {
      button.setButtonType(.toggle)
    }
    button.isBordered = false
    if let title {
      button.title = title
      button.image = nil
      button.font = NSFont.systemFont(ofSize: 17, weight: .semibold)
    }
    button.wantsLayer = true
    button.layer?.cornerRadius = 7
    button.layer?.masksToBounds = true
    button.contentTintColor = .labelColor
    button.toolTip = tooltip
    button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
    button.widthAnchor.constraint(equalToConstant: 34).isActive = true
    button.heightAnchor.constraint(equalToConstant: 34).isActive = true
    return button
  }

  @objc private func selectRectangle(_ sender: NSButton) {
    commitTextEntry()
    selectedTool = selectedTool == .rectangle ? .none : .rectangle
    updateToolStates()
  }

  @objc private func selectOval(_ sender: NSButton) {
    commitTextEntry()
    selectedTool = selectedTool == .oval ? .none : .oval
    updateToolStates()
  }

  @objc private func selectArrow(_ sender: NSButton) {
    commitTextEntry()
    selectedTool = selectedTool == .arrow ? .none : .arrow
    updateToolStates()
  }

  @objc private func selectText(_ sender: NSButton) {
    commitTextEntry()
    selectedTool = selectedTool == .text ? .none : .text
    updateToolStates()
  }

  private func updateToolStates() {
    for (tool, button) in toolButtons {
      let isSelected = selectedTool == tool
      button.state = isSelected ? .on : .off
      button.contentTintColor = isSelected ? .white : .labelColor
      button.layer?.backgroundColor = isSelected
        ? NSColor.controlAccentColor.cgColor
        : NSColor.clear.cgColor
    }
    window?.invalidateCursorRects(for: self)
  }

  @objc private func togglePin(_ sender: NSButton) {
    isPinned.toggle()
    hostWindow?.level = isPinned ? .floating : .normal
    hostWindow?.collectionBehavior = isPinned
      ? [.canJoinAllSpaces, .fullScreenAuxiliary]
      : [.fullScreenAuxiliary]
    opacityPanel.isHidden = !isPinned
    if !isPinned {
      opacitySlider.doubleValue = 1
      hostWindow?.alphaValue = 1
    }
    sender.image = NSImage(
      systemSymbolName: isPinned ? "pin.fill" : "pin",
      accessibilityDescription: String(localized: "Pin")
    )
    sender.toolTip = String(localized: isPinned ? "Unpin" : "Pin")
  }

  @objc private func updateOpacity(_ sender: NSSlider) {
    guard isPinned else { return }
    hostWindow?.alphaValue = CGFloat(sender.doubleValue)
  }

  @objc private func downloadImage() {
    commitTextEntry()
    let panel = NSSavePanel()
    activeSavePanel = panel
    panel.animationBehavior = .none
    panel.allowedContentTypes = [.png]
    panel.nameFieldStringValue = "FT-\(Int(Date().timeIntervalSince1970 * 1000)).png"
    panel.canCreateDirectories = true

    guard panel.runModal() == .OK, let url = panel.url else {
      releaseSavePanelAfterCurrentEvent()
      return
    }
    guard let pngData = pngData() else {
      releaseSavePanelAfterCurrentEvent()
      showSaveError(String(localized: "Unable to create PNG data."))
      return
    }

    do {
      try pngData.write(to: url, options: .atomic)
      closeHostWindowAfterCurrentEvent()
    } catch {
      releaseSavePanelAfterCurrentEvent()
      showSaveError(error.localizedDescription)
    }
  }

  private func closeHostWindowAfterCurrentEvent() {
    guard let hostWindow else { return }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self, weak hostWindow] in
      self?.activeSavePanel = nil
      hostWindow?.dismissWindow()
    }
  }

  private func releaseSavePanelAfterCurrentEvent() {
    DispatchQueue.main.async { [weak self] in
      self?.activeSavePanel = nil
    }
  }

  private func showSaveError(_ message: String) {
    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = String(localized: "Could not save image")
    alert.informativeText = message
    alert.runModal()
  }

  @objc private func copyImageToPasteboard() {
    commitTextEntry()
    guard let pngData = pngData() else { return }

    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setData(pngData, forType: .png)
    hostWindow?.dismissWindow()
  }

  private func beginTextEntry(at point: NSPoint, imagePoint: NSPoint) {
    commitTextEntry()

    let font = textFont(in: imageRect)
    let field = NSTextField(frame: NSRect(
      x: point.x,
      y: point.y - 3,
      width: min(240, max(100, imageRect.maxX - point.x - 4)),
      height: max(28, font.pointSize + 12)
    ))
    field.font = font
    field.textColor = .systemRed
    field.placeholderString = String(localized: "Text")
    field.target = self
    field.action = #selector(commitTextEntry)
    addSubview(field)

    textField = field
    textEntryPoint = imagePoint
    window?.makeFirstResponder(field)
  }

  @objc private func commitTextEntry() {
    guard let textField, let textEntryPoint else { return }

    let text = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    if !text.isEmpty {
      annotations.append(Annotation(tool: .text, start: textEntryPoint, end: textEntryPoint, text: text))
    }
    textField.removeFromSuperview()
    self.textField = nil
    self.textEntryPoint = nil
    window?.makeFirstResponder(self)
    needsDisplay = true
  }

  private var imageRect: NSRect {
    let available = NSRect(
      x: 12,
      y: 54,
      width: max(0, bounds.width - 24),
      height: max(0, bounds.height - 66)
    )
    guard image.size.width > 0, image.size.height > 0 else { return .zero }

    let scale = min(available.width / image.size.width, available.height / image.size.height)
    let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    return NSRect(
      x: available.midX - size.width / 2,
      y: available.midY - size.height / 2,
      width: size.width,
      height: size.height
    )
  }

  private func imagePoint(from point: NSPoint) -> NSPoint? {
    let rect = imageRect
    guard rect.contains(point), rect.width > 0, rect.height > 0 else { return nil }
    return NSPoint(
      x: (point.x - rect.minX) / rect.width * image.size.width,
      y: (point.y - rect.minY) / rect.height * image.size.height
    )
  }

  private func annotationIndex(at point: NSPoint) -> Int? {
    let rect = imageRect
    let canvasPoint = viewPoint(point, in: rect)
    let hitTolerance = max(8, rect.width / max(image.size.width, 1) * 18)

    for index in annotations.indices.reversed() {
      let annotation = annotations[index]
      let start = self.viewPoint(annotation.start, in: rect)
      let end = self.viewPoint(annotation.end, in: rect)

      switch annotation.tool {
      case .rectangle, .oval:
        let bounds = NSRect(
          x: min(start.x, end.x) - hitTolerance,
          y: min(start.y, end.y) - hitTolerance,
          width: abs(end.x - start.x) + hitTolerance * 2,
          height: abs(end.y - start.y) + hitTolerance * 2
        )
        if bounds.contains(canvasPoint) {
          return index
        }
      case .arrow:
        if distance(from: canvasPoint, toSegmentFrom: start, to: end) <= hitTolerance {
          return index
        }
      case .text:
        guard let text = annotation.text else { continue }
        let attributes: [NSAttributedString.Key: Any] = [
          .font: textFont(in: rect)
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let textRect = NSRect(
          x: start.x - hitTolerance,
          y: start.y - hitTolerance,
          width: textSize.width + hitTolerance * 2,
          height: textSize.height + hitTolerance * 2
        )
        if textRect.contains(canvasPoint) {
          return index
        }
      case .none:
        continue
      }
    }
    return nil
  }

  private func distance(from point: NSPoint, toSegmentFrom start: NSPoint, to end: NSPoint) -> CGFloat {
    let deltaX = end.x - start.x
    let deltaY = end.y - start.y
    let lengthSquared = deltaX * deltaX + deltaY * deltaY
    guard lengthSquared > 0 else {
      return hypot(point.x - start.x, point.y - start.y)
    }

    let projection = max(0, min(1, ((point.x - start.x) * deltaX + (point.y - start.y) * deltaY) / lengthSquared))
    let closest = NSPoint(
      x: start.x + projection * deltaX,
      y: start.y + projection * deltaY
    )
    return hypot(point.x - closest.x, point.y - closest.y)
  }

  private func draw(_ annotation: Annotation, in rect: NSRect) {
    let start = viewPoint(annotation.start, in: rect)
    let end = viewPoint(annotation.end, in: rect)
    let path = NSBezierPath()
    path.lineWidth = max(2, rect.width / max(image.size.width, 1) * 3)
    NSColor.systemRed.setStroke()

    switch annotation.tool {
    case .rectangle:
      path.appendRect(NSRect(
        x: min(start.x, end.x),
        y: min(start.y, end.y),
        width: abs(end.x - start.x),
        height: abs(end.y - start.y)
      ))
      path.stroke()
    case .oval:
      let ovalRect = NSRect(
        x: min(start.x, end.x),
        y: min(start.y, end.y),
        width: abs(end.x - start.x),
        height: abs(end.y - start.y)
      )
      NSBezierPath(ovalIn: ovalRect).stroke()
    case .arrow:
      path.move(to: start)
      path.line(to: end)
      path.stroke()

      let angle = atan2(end.y - start.y, end.x - start.x)
      let headLength = max(8, rect.width / max(image.size.width, 1) * 14)
      let headAngle = CGFloat.pi / 7
      let left = NSPoint(
        x: end.x - cos(angle - headAngle) * headLength,
        y: end.y - sin(angle - headAngle) * headLength
      )
      let right = NSPoint(
        x: end.x - cos(angle + headAngle) * headLength,
        y: end.y - sin(angle + headAngle) * headLength
      )
      let head = NSBezierPath()
      head.move(to: left)
      head.line(to: end)
      head.line(to: right)
      head.stroke()
    case .text:
      guard let text = annotation.text else { return }
      let attributes: [NSAttributedString.Key: Any] = [
        .font: textFont(in: rect),
        .foregroundColor: NSColor.systemRed
      ]
      NSAttributedString(string: text, attributes: attributes).draw(at: start)
    case .none:
      break
    }
  }

  private func viewPoint(_ point: NSPoint, in rect: NSRect) -> NSPoint {
    NSPoint(
      x: rect.minX + point.x / image.size.width * rect.width,
      y: rect.minY + point.y / image.size.height * rect.height
    )
  }

  private func textFont(in rect: NSRect) -> NSFont {
    let scale = rect.width / max(image.size.width, 1)
    return NSFont.systemFont(ofSize: max(12, 20 * scale), weight: .medium)
  }

  private func pngData() -> Data? {
    var proposedRect = NSRect(origin: .zero, size: image.size)
    guard let sourceCGImage = image.cgImage(
      forProposedRect: &proposedRect,
      context: nil,
      hints: nil
    ) else {
      return nil
    }

    let outputSize = NSSize(
      width: max(1, sourceCGImage.width),
      height: max(1, sourceCGImage.height)
    )
    guard let bitmap = NSBitmapImageRep(
      bitmapDataPlanes: nil,
      pixelsWide: Int(outputSize.width),
      pixelsHigh: Int(outputSize.height),
      bitsPerSample: 8,
      samplesPerPixel: 4,
      hasAlpha: true,
      isPlanar: false,
      colorSpaceName: .deviceRGB,
      bitmapFormat: [],
      bytesPerRow: 0,
      bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
      return nil
    }

    let outputRect = NSRect(origin: .zero, size: outputSize)
    let sourceImage = NSImage(cgImage: sourceCGImage, size: outputSize)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    NSColor.clear.setFill()
    outputRect.fill()
    sourceImage.draw(in: outputRect, from: .zero, operation: .copy, fraction: 1)
    annotations.forEach { draw($0, in: outputRect) }
    NSGraphicsContext.restoreGraphicsState()

    return bitmap.representation(using: .png, properties: [:])
  }
}

private final class OpacitySlider: NSSlider {

  override func draw(_ dirtyRect: NSRect) {
    let range = max(maxValue - minValue, Double.leastNonzeroMagnitude)
    let progress = CGFloat((doubleValue - minValue) / range)
    let width = bounds.width * min(max(progress, 0), 1)
    guard width > 0 else { return }

    let track = NSRect(x: 0, y: (bounds.height - 4) / 2, width: width, height: 4)
    NSColor.controlAccentColor.setFill()
    NSBezierPath(roundedRect: track, xRadius: 2, yRadius: 2).fill()
  }
}
