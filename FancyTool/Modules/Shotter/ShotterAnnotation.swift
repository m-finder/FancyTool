import AppKit

enum ShotterTool: CaseIterable, Hashable {
  case none, rectangle, oval, arrow, pen, highlighter, text, number, redact
}

enum ShotterAnnotationColor: Int, CaseIterable {
  case red, orange, yellow, green, blue, purple, white, black

  /// Fixed sRGB values keep saved annotations identical in light and dark mode.
  var nsColor: NSColor {
    let components: (CGFloat, CGFloat, CGFloat) = switch self {
    case .red: (0.96, 0.25, 0.32)
    case .orange: (1, 0.52, 0.19)
    case .yellow: (1, 0.82, 0.20)
    case .green: (0.20, 0.76, 0.48)
    case .blue: (0.22, 0.55, 1)
    case .purple: (0.63, 0.40, 0.97)
    case .white: (1, 1, 1)
    case .black: (0.08, 0.10, 0.14)
    }
    return NSColor(srgbRed: components.0, green: components.1, blue: components.2, alpha: 1)
  }

  var title: String {
    switch self {
    case .red: String(localized: "Red")
    case .orange: String(localized: "Orange")
    case .yellow: String(localized: "Yellow")
    case .green: String(localized: "Green")
    case .blue: String(localized: "Blue")
    case .purple: String(localized: "Purple")
    case .white: String(localized: "White")
    case .black: String(localized: "Black")
    }
  }

  fileprivate var badgeTextColor: NSColor {
    switch self {
    case .black: .white
    default: .black
    }
  }
}

struct ShotterAnnotationStyle: Equatable {
  var color: ShotterAnnotationColor = .red
  var lineWidth: CGFloat = 3
  var fontSize: CGFloat = 22

  fileprivate var strokeWidth: CGFloat { lineWidth.isFinite ? min(40, max(0.5, lineWidth)) : 3 }
  fileprivate var pointSize: CGFloat { fontSize.isFinite ? min(200, max(8, fontSize)) : 22 }
}

/// Geometry is stored in the captured image's logical point space. The same
/// renderer maps it into the preview or the original-resolution exported PNG.
struct ShotterAnnotation: Equatable {
  var tool: ShotterTool
  var start: NSPoint
  var end: NSPoint
  var text: String?
  var points: [NSPoint]
  var number: Int
  var style: ShotterAnnotationStyle

  init(tool: ShotterTool, start: NSPoint, end: NSPoint, text: String? = nil,
       points: [NSPoint] = [], number: Int = 1, style: ShotterAnnotationStyle = .init()) {
    self.tool = tool
    self.start = start
    self.end = end
    self.text = text
    self.points = points
    self.number = number
    self.style = style
  }

  var bounds: NSRect {
    switch tool {
    case .none: return .zero
    case .rectangle, .oval:
      return shapeRect.insetBy(dx: -strokeWidth / 2, dy: -strokeWidth / 2)
    case .redact:
      return shapeRect
    case .arrow:
      return Self.bounds(of: [start, end] + arrowHead).insetBy(dx: -strokeWidth / 2, dy: -strokeWidth / 2)
    case .pen, .highlighter:
      return Self.bounds(of: strokePoints).insetBy(dx: -strokeWidth / 2, dy: -strokeWidth / 2)
    case .text:
      return NSRect(origin: start, size: label.size())
    case .number:
      return NSRect(x: start.x - badgeRadius, y: start.y - badgeRadius,
                    width: badgeRadius * 2, height: badgeRadius * 2)
    }
  }

  func contains(_ point: NSPoint, tolerance: CGFloat) -> Bool {
    let tolerance = max(0, tolerance)
    guard bounds.insetBy(dx: -tolerance, dy: -tolerance).contains(point) else { return false }
    let radius = strokeWidth / 2 + tolerance
    switch tool {
    case .none:
      return false
    case .rectangle:
      let rect = shapeRect
      let corners = [NSPoint(x: rect.minX, y: rect.minY), NSPoint(x: rect.maxX, y: rect.minY),
                     NSPoint(x: rect.maxX, y: rect.maxY), NSPoint(x: rect.minX, y: rect.maxY)]
      return Self.hits(point, polyline: corners + [corners[0]], radius: radius)
    case .oval:
      // Sampling the outline avoids selecting empty interiors and remains
      // consistent for highly eccentric ellipses and a fixed point tolerance.
      let rect = shapeRect
      let outline = (0...96).map { step in
        let angle = CGFloat(step) / 96 * .pi * 2
        return NSPoint(x: rect.midX + cos(angle) * rect.width / 2,
                       y: rect.midY + sin(angle) * rect.height / 2)
      }
      return Self.hits(point, polyline: outline, radius: radius)
    case .arrow:
      return Self.hits(point, polyline: [start, end], radius: radius) ||
        Self.hits(point, polyline: [arrowHead[0], end, arrowHead[1]], radius: radius)
    case .pen, .highlighter:
      return Self.hits(point, polyline: strokePoints, radius: radius)
    case .number:
      return hypot(point.x - start.x, point.y - start.y) <= badgeRadius + tolerance
    case .text, .redact:
      return true
    }
  }

  func translated(by offset: NSPoint) -> Self {
    func moved(_ point: NSPoint) -> NSPoint { NSPoint(x: point.x + offset.x, y: point.y + offset.y) }
    var copy = self
    copy.start = moved(start)
    copy.end = moved(end)
    copy.points = points.map(moved)
    return copy
  }

  func draw(in rect: NSRect, imageSize: NSSize) {
    guard imageSize.width > 0, imageSize.height > 0, !rect.isEmpty,
          let context = NSGraphicsContext.current?.cgContext else { return }
    context.saveGState()
    defer { context.restoreGState() }
    context.translateBy(x: rect.minX, y: rect.minY)
    context.scaleBy(x: rect.width / imageSize.width, y: rect.height / imageSize.height)

    let path = NSBezierPath()
    path.lineWidth = strokeWidth
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    style.color.nsColor.setStroke()
    style.color.nsColor.setFill()
    switch tool {
    case .none:
      break
    case .rectangle:
      path.appendRect(shapeRect)
      path.stroke()
    case .oval:
      path.appendOval(in: shapeRect)
      path.stroke()
    case .arrow:
      path.move(to: start)
      path.line(to: end)
      path.move(to: arrowHead[0])
      path.line(to: end)
      path.line(to: arrowHead[1])
      path.stroke()
    case .pen, .highlighter:
      let stroke = strokePoints
      path.move(to: stroke[0])
      stroke.dropFirst().forEach { path.line(to: $0) }
      if tool == .highlighter {
        // Composite the entire gesture once: slow movement and self-crossings
        // must not darken individual segments of a highlighter mark.
        context.setAlpha(0.28)
        context.beginTransparencyLayer(auxiliaryInfo: nil)
      }
      if stroke.allSatisfy({ $0 == stroke[0] }) {
        NSBezierPath(ovalIn: NSRect(x: stroke[0].x - strokeWidth / 2, y: stroke[0].y - strokeWidth / 2,
                                   width: strokeWidth, height: strokeWidth)).fill()
      } else {
        path.stroke()
      }
      if tool == .highlighter { context.endTransparencyLayer() }
    case .text:
      label.draw(at: start)
    case .number:
      NSBezierPath(ovalIn: bounds).fill()
      let numberLabel = NSAttributedString(string: String(number), attributes: [
        .font: NSFont.monospacedDigitSystemFont(ofSize: style.pointSize * 0.8, weight: .bold),
        .foregroundColor: style.color.badgeTextColor
      ])
      let size = numberLabel.size()
      numberLabel.draw(at: NSPoint(x: start.x - size.width / 2, y: start.y - size.height / 2))
    case .redact:
      // .copy and a solid color make redaction independent of annotation
      // color/opacity, including over transparent source images.
      context.setShouldAntialias(false)
      NSColor.black.setFill()
      shapeRect.fill(using: .copy)
    }
  }

  private var strokeWidth: CGFloat {
    tool == .highlighter ? max(12, style.strokeWidth * 4) : style.strokeWidth
  }

  private var shapeRect: NSRect {
    NSRect(x: min(start.x, end.x), y: min(start.y, end.y),
           width: abs(end.x - start.x), height: abs(end.y - start.y))
  }

  private var strokePoints: [NSPoint] { points.isEmpty ? [start, end] : points }

  private var label: NSAttributedString {
    NSAttributedString(string: text ?? "", attributes: [
      .font: NSFont.systemFont(ofSize: style.pointSize, weight: .medium),
      .foregroundColor: style.color.nsColor
    ])
  }

  private var badgeRadius: CGFloat {
    let width = (String(number) as NSString).size(withAttributes: [
      .font: NSFont.monospacedDigitSystemFont(ofSize: style.pointSize * 0.8, weight: .bold)
    ]).width
    return max(12, style.pointSize * 0.67, width / 2 + 6)
  }

  private var arrowHead: [NSPoint] {
    let angle = atan2(end.y - start.y, end.x - start.x)
    let length = max(10, style.strokeWidth * 3.5)
    return [-CGFloat.pi / 6, CGFloat.pi / 6].map { offset in
      NSPoint(x: end.x - cos(angle + offset) * length, y: end.y - sin(angle + offset) * length)
    }
  }

  private static func bounds(of points: [NSPoint]) -> NSRect {
    guard let first = points.first else { return .zero }
    let minX = points.reduce(first.x) { min($0, $1.x) }
    let maxX = points.reduce(first.x) { max($0, $1.x) }
    let minY = points.reduce(first.y) { min($0, $1.y) }
    let maxY = points.reduce(first.y) { max($0, $1.y) }
    return NSRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
  }

  private static func hits(_ point: NSPoint, polyline: [NSPoint], radius: CGFloat) -> Bool {
    guard let first = polyline.first else { return false }
    if polyline.count == 1 { return hypot(point.x - first.x, point.y - first.y) <= radius }
    return zip(polyline, polyline.dropFirst()).contains { start, end in
      let dx = end.x - start.x, dy = end.y - start.y
      let squaredLength = dx * dx + dy * dy
      let t = squaredLength > 0
        ? min(1, max(0, ((point.x - start.x) * dx + (point.y - start.y) * dy) / squaredLength))
        : 0
      return hypot(point.x - start.x - dx * t, point.y - start.y - dy * t) <= radius
    }
  }
}
