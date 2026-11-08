import AppKit

@MainActor
final class ShotterToolbarView: NSView {
  enum Action { case undo, redo, delete, pin, save, copy, close }
  static let preferredSize = NSSize(width: 636, height: 104)

  var onTool: ((ShotterTool) -> Void)?
  var onColor: ((ShotterAnnotationColor) -> Void)?
  var onWidth: ((CGFloat) -> Void)?
  var onFontSize: ((CGFloat) -> Void)?
  var onOpacity: ((CGFloat) -> Void)?
  var onAction: ((Action) -> Void)?

  private let content = NSView()
  private let toolsRow = NSStackView()
  private let styleRow = NSStackView()
  private var toolButtons: [ShotterTool: ShotterToolButton] = [:]
  private var actionButtons: [Action: ShotterToolButton] = [:]
  private var swatches: [ShotterAnnotationColor: ShotterColorButton] = [:]
  private let widthControl = NSSegmentedControl()
  private let fontControl = NSPopUpButton(frame: .zero, pullsDown: false)
  private let opacity = NSSlider(value: 1, minValue: 0.2, maxValue: 1, target: nil, action: nil)
  private let dimensions = NSTextField(labelWithString: "")
  private let widths: [CGFloat] = [2, 4, 7]
  private let sizes: [CGFloat] = [14, 18, 22, 28, 36, 48]

  override init(frame: NSRect) {
    super.init(frame: frame)
    let surface: NSView
    if #available(macOS 26.0, *) {
      let glass = NSGlassEffectView(frame: bounds)
      glass.style = .regular
      glass.cornerRadius = 18
      glass.contentView = content
      surface = glass
    } else {
      let material = NSVisualEffectView(frame: bounds)
      material.material = .popover
      material.blendingMode = .behindWindow
      material.state = .active
      material.wantsLayer = true
      material.layer?.cornerRadius = 18
      material.layer?.masksToBounds = true
      material.addSubview(content)
      content.autoresizingMask = [.width, .height]
      surface = material
    }
    surface.autoresizingMask = [.width, .height]
    addSubview(surface)
    content.frame = bounds
    // AppKit can resolve stack constraints as soon as buttons are added.
    // Give both rows their real widths before that first layout pass.
    layoutRows()
    for row in [toolsRow, styleRow] {
      row.orientation = .horizontal
      row.alignment = .centerY
      row.distribution = .fill
      row.spacing = 4
      content.addSubview(row)
    }
    let definitions: [(ShotterTool, String, String)] = [
      (.none, "cursorarrow", String(localized: "Select / Move (V)")),
      (.rectangle, "rectangle", String(localized: "Rectangle (R)")),
      (.oval, "circle", String(localized: "Ellipse (O)")),
      (.arrow, "arrow.up.right", String(localized: "Arrow (A)")),
      (.pen, "pencil.tip", String(localized: "Pen (P)")),
      (.highlighter, "highlighter", String(localized: "Highlighter (H)")),
      (.text, "", String(localized: "Text (T)")),
      (.number, "1.circle", String(localized: "Step number (N)")),
      (.redact, "rectangle.inset.filled", String(localized: "Solid redaction (X)"))
    ]
    for (tool, symbol, title) in definitions {
      let button = ShotterToolButton(symbol: symbol, title: title, glyph: tool == .text ? "T" : nil)
      button.onPress = { [weak self] in self?.onTool?(tool) }
      toolButtons[tool] = button
      toolsRow.addArrangedSubview(button)
    }
    toolsRow.addArrangedSubview(separator())
    addAction(.undo, symbol: "arrow.uturn.backward", title: String(localized: "Undo (⌘Z)"))
    addAction(.redo, symbol: "arrow.uturn.forward", title: String(localized: "Redo (⇧⌘Z)"))
    addAction(.delete, symbol: "trash", title: String(localized: "Delete selected annotation"))
    toolsRow.addArrangedSubview(spacer())
    addAction(.pin, symbol: "pin", title: String(localized: "Pin"))
    addAction(.save, symbol: "square.and.arrow.down", title: String(localized: "Save PNG (⌘S)"))
    addAction(.copy, symbol: "doc.on.doc", title: String(localized: "Copy (⌘C)"))
    toolsRow.addArrangedSubview(separator())
    addAction(.close, symbol: "xmark", title: String(localized: "Close (Esc)"))

    for color in ShotterAnnotationColor.allCases {
      let button = ShotterColorButton(color: color)
      button.onPress = { [weak self] in self?.onColor?(color) }
      swatches[color] = button
      styleRow.addArrangedSubview(button)
    }
    styleRow.addArrangedSubview(separator())
    widthControl.segmentCount = widths.count
    widthControl.segmentStyle = .separated
    widthControl.trackingMode = .selectOne
    widthControl.controlSize = .small
    widthControl.target = self
    widthControl.action = #selector(changeWidth)
    widthControl.toolTip = String(localized: "Stroke width")
    widthControl.setAccessibilityLabel(String(localized: "Stroke width"))
    for (index, width) in widths.enumerated() {
      let image = NSImage(size: NSSize(width: 24, height: 14), flipped: false) { _ in
        NSColor.labelColor.setStroke()
        let path = NSBezierPath()
        path.lineWidth = width
        path.lineCapStyle = .round
        path.move(to: NSPoint(x: 4, y: 7)); path.line(to: NSPoint(x: 20, y: 7)); path.stroke()
        return true
      }
      image.isTemplate = true
      widthControl.setImage(image, forSegment: index)
      widthControl.setWidth(30, forSegment: index)
      widthControl.setToolTip("\(Int(width)) pt", forSegment: index)
    }
    styleRow.addArrangedSubview(widthControl)
    fontControl.controlSize = .small
    fontControl.font = .systemFont(ofSize: 11)
    fontControl.addItems(withTitles: sizes.map { "\(Int($0)) pt" })
    fontControl.target = self
    fontControl.action = #selector(changeFont)
    fontControl.toolTip = String(localized: "Text size")
    fontControl.setAccessibilityLabel(String(localized: "Text size"))
    fontControl.widthAnchor.constraint(equalToConstant: 72).isActive = true
    styleRow.addArrangedSubview(fontControl)
    styleRow.addArrangedSubview(spacer())
    opacity.controlSize = .small
    opacity.isContinuous = true
    opacity.target = self
    opacity.action = #selector(changeOpacity)
    opacity.toolTip = String(localized: "Pinned image opacity")
    opacity.setAccessibilityLabel(String(localized: "Pinned image opacity"))
    opacity.widthAnchor.constraint(equalToConstant: 90).isActive = true
    opacity.isHidden = true
    styleRow.addArrangedSubview(opacity)
    dimensions.font = .monospacedDigitSystemFont(ofSize: 10, weight: .medium)
    dimensions.textColor = .secondaryLabelColor
    dimensions.setContentCompressionResistancePriority(.required, for: .horizontal)
    styleRow.addArrangedSubview(dimensions)
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func layout() {
    layoutRows()
    super.layout()
  }

  private func layoutRows() {
    toolsRow.frame = NSRect(x: 12, y: bounds.height - 46, width: bounds.width - 24, height: 34)
    styleRow.frame = NSRect(x: 16, y: 12, width: bounds.width - 32, height: 26)
  }

  func update(tool: ShotterTool, selectionTool: ShotterTool?, style: ShotterAnnotationStyle, canUndo: Bool, canRedo: Bool,
              hasSelection: Bool, isPinned: Bool, pixelSize: NSSize) {
    toolButtons.forEach { $0.value.isActive = $0.key == tool }
    actionButtons[.undo]?.isEnabled = canUndo
    actionButtons[.redo]?.isEnabled = canRedo
    actionButtons[.delete]?.isEnabled = hasSelection
    actionButtons[.pin]?.isActive = isPinned
    actionButtons[.pin]?.toolTip = String(localized: isPinned ? "Unpin" : "Pin")
    swatches.forEach { $0.value.isActive = $0.key == style.color }
    let styleTool = selectionTool ?? tool
    let colorEnabled = styleTool != .redact && styleTool != .none
    swatches.values.forEach { $0.isEnabled = colorEnabled }
    widthControl.isEnabled = [.rectangle, .oval, .arrow, .pen, .highlighter].contains(styleTool)
    fontControl.isEnabled = [.text, .number].contains(styleTool)
    widthControl.selectedSegment = widths.enumerated().min(by: { abs($0.element-style.lineWidth) < abs($1.element-style.lineWidth) })?.offset ?? 0
    fontControl.selectItem(at: sizes.enumerated().min(by: { abs($0.element-style.fontSize) < abs($1.element-style.fontSize) })?.offset ?? 2)
    opacity.isHidden = !isPinned
    if !isPinned { opacity.doubleValue = 1 }
    dimensions.stringValue = "\(Int(pixelSize.width)) × \(Int(pixelSize.height)) px"
    needsLayout = true
  }

  private func addAction(_ action: Action, symbol: String, title: String) {
    let button = ShotterToolButton(symbol: symbol, title: title)
    button.onPress = { [weak self] in self?.onAction?(action) }
    button.isEmphasized = action == .copy
    actionButtons[action] = button
    toolsRow.addArrangedSubview(button)
  }

  private func separator() -> NSView {
    let view = NSBox()
    view.boxType = .custom
    view.borderWidth = 0
    view.fillColor = .separatorColor
    view.widthAnchor.constraint(equalToConstant: 1).isActive = true
    view.heightAnchor.constraint(equalToConstant: 18).isActive = true
    return view
  }

  private func spacer() -> NSView {
    let view = NSView()
    view.setContentHuggingPriority(.defaultLow, for: .horizontal)
    view.widthAnchor.constraint(greaterThanOrEqualToConstant: 6).isActive = true
    return view
  }

  @objc private func changeWidth() { onWidth?(widths[max(0, widthControl.selectedSegment)]) }
  @objc private func changeFont() { onFontSize?(sizes[max(0, fontControl.indexOfSelectedItem)]) }
  @objc private func changeOpacity() { onOpacity?(CGFloat(opacity.doubleValue)) }
}

@MainActor
private final class ShotterToolButton: NSButton {
  var onPress: (() -> Void)?
  var isActive = false { didSet { if isActive != oldValue { refresh() } } }
  var isEmphasized = false { didSet { if isEmphasized != oldValue { refresh() } } }
  private var hovered = false
  private var tracking: NSTrackingArea?
  override var isEnabled: Bool { didSet { if isEnabled != oldValue { refresh() } } }

  init(symbol: String, title: String, glyph: String? = nil) {
    super.init(frame: .zero)
    self.title = glyph ?? ""
    image = glyph == nil ? NSImage(systemSymbolName: symbol, accessibilityDescription: title) : nil
    symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
    imagePosition = glyph != nil ? .noImage : .imageOnly
    font = .systemFont(ofSize: 17, weight: .medium)
    toolTip = title
    setAccessibilityLabel(title)
    isBordered = false
    bezelStyle = .regularSquare
    focusRingType = .none
    target = self
    action = #selector(pressed)
    wantsLayer = true
    layer?.cornerRadius = 9
    widthAnchor.constraint(equalToConstant: 32).isActive = true
    heightAnchor.constraint(equalToConstant: 32).isActive = true
    refresh()
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    refresh()
  }
  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    if let tracking { removeTrackingArea(tracking) }
    let area = NSTrackingArea(rect: .zero, options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect], owner: self)
    addTrackingArea(area); tracking = area
  }
  override func mouseEntered(with event: NSEvent) { hovered = true; refresh() }
  override func mouseExited(with event: NSEvent) { hovered = false; refresh() }
  private func refresh() {
    contentTintColor = !isEnabled ? .tertiaryLabelColor : (isActive ? .controlAccentColor : .labelColor)
    let backgroundOpacity: CGFloat = hovered && isEnabled ? 0.09 : (isEmphasized ? 0.05 : 0)
    let color: NSColor = isActive ? NSColor.controlAccentColor.withAlphaComponent(0.15) : NSColor.labelColor.withAlphaComponent(backgroundOpacity)
    layer?.backgroundColor = color.cgColor
    alphaValue = isEnabled ? 1 : 0.45
  }
  @objc private func pressed() { onPress?() }
}

@MainActor
private final class ShotterColorButton: NSButton {
  let color: ShotterAnnotationColor
  var onPress: (() -> Void)?
  var isActive = false { didSet { if isActive != oldValue { needsDisplay = true } } }
  override var isEnabled: Bool { didSet { if isEnabled != oldValue { needsDisplay = true } } }
  init(color: ShotterAnnotationColor) {
    self.color = color
    super.init(frame: .zero)
    isBordered = false
    title = ""
    toolTip = color.title
    setAccessibilityLabel(color.title)
    target = self; action = #selector(pressed)
    widthAnchor.constraint(equalToConstant: 22).isActive = true
    heightAnchor.constraint(equalToConstant: 24).isActive = true
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
  override func draw(_ dirtyRect: NSRect) {
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current?.cgContext.setAlpha(isEnabled ? 1 : 0.35)
    let circle = NSBezierPath(ovalIn: bounds.insetBy(dx: 3, dy: 4))
    color.nsColor.setFill(); circle.fill()
    NSColor.labelColor.withAlphaComponent(0.18).setStroke(); circle.lineWidth = 0.7; circle.stroke()
    if isActive {
      let ring = NSBezierPath(ovalIn: bounds.insetBy(dx: 0.5, dy: 1.5))
      NSColor.controlAccentColor.setStroke(); ring.lineWidth = 1.5; ring.stroke()
    }
    NSGraphicsContext.restoreGraphicsState()
  }
  @objc private func pressed() { onPress?() }
}
