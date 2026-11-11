import AppKit
import SwiftUI

enum TexterBorderStyle {
  static let horizontalPadding: CGFloat = 7
  static let cornerRadius: CGFloat = 5
  static let lineWidth: CGFloat = 1
  static let normalLineWidth: CGFloat = 0.65
  static let cycleDuration: TimeInterval = 3

  /// AppKit's unflipped coordinates: start on the top edge, then go right,
  /// down, left, and up. The dash phase determines the direction of travel.
  static func outline(in bounds: CGRect, lineWidth: CGFloat = TexterBorderStyle.lineWidth) -> (path: CGPath, length: CGFloat) {
    let rect = bounds.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
    let radius = max(0, min(cornerRadius, min(rect.width, rect.height) / 2))
    let path = CGMutablePath()
    path.move(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.maxY))
    path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius), radius: radius,
                startAngle: .pi / 2, endAngle: 0, clockwise: true)
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + radius))
    path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius), radius: radius,
                startAngle: 0, endAngle: -.pi / 2, clockwise: true)
    path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.minY))
    path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.minY + radius), radius: radius,
                startAngle: -.pi / 2, endAngle: -.pi, clockwise: true)
    path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - radius))
    path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius), radius: radius,
                startAngle: .pi, endAngle: .pi / 2, clockwise: true)
    path.closeSubpath()
    return (path, 2 * (rect.width + rect.height - 4 * radius) + 2 * .pi * radius)
  }
}

/// Animates a highlight along the rounded path. Normal borders use a subtle
/// system foreground; rainbow borders use their own palette and direction.
struct TexterBorderView: NSViewRepresentable {
  let colors: [Color]
  let rainbow: Bool
  let bounds: CGSize
  var clockwise = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorScheme) private var colorScheme

  func makeCoordinator() -> Coordinator { Coordinator() }

  func makeNSView(context: Context) -> ShimmerVisibilityView {
    let view = ShimmerVisibilityView(frame: NSRect(origin: .zero, size: bounds))
    view.wantsLayer = true
    context.coordinator.install(in: view)
    view.onVisibilityChange = { [coordinator = context.coordinator] in coordinator.setVisible($0) }
    return view
  }

  func updateNSView(_ view: ShimmerVisibilityView, context: Context) {
    let appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua) ?? view.effectiveAppearance
    appearance.performAsCurrentDrawingAppearance {
      context.coordinator.configure(colors: colors, animated: !reduceMotion, rainbow: rainbow, clockwise: clockwise,
                                    scale: view.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2)
    }
    context.coordinator.layout(in: CGRect(origin: .zero, size: bounds))
  }

  static func dismantleNSView(_ view: ShimmerVisibilityView, coordinator: Coordinator) {
    view.dismantle()
    coordinator.stop()
  }

  @MainActor
  final class Coordinator {
    private let base = CAGradientLayer()
    private let border = CAShapeLayer()
    private let flow = CAGradientLayer()
    private let trail = CALayer()
    private var segments: [CAShapeLayer] = []
    private var animated = false
    private var clockwise = false
    private var visible = false
    private var length: CGFloat = 0
    private var previousBounds = CGRect.zero

    func install(in view: NSView) {
      guard let root = view.layer else { return }
      for gradient in [base, flow] {
        gradient.startPoint = CGPoint(x: 0, y: 1)
        gradient.endPoint = CGPoint(x: 1, y: 0)
        root.addSublayer(gradient)
      }
      border.fillColor = nil
      border.strokeColor = NSColor.white.cgColor
      border.lineWidth = TexterBorderStyle.lineWidth
      base.mask = border
      flow.mask = trail
      for index in 0..<12 {
        let segment = CAShapeLayer()
        segment.fillColor = nil
        segment.strokeColor = NSColor.white.cgColor
        segment.lineWidth = TexterBorderStyle.lineWidth
        segment.lineCap = .butt
        segment.opacity = Float(index + 1) / 12
        trail.addSublayer(segment)
        segments.append(segment)
      }
    }

    func configure(colors: [Color], animated: Bool, rainbow: Bool = true, clockwise: Bool = false, scale: CGFloat = 2) {
      let resolved = !rainbow || colors.isEmpty ? [NSColor.labelColor.cgColor] : colors.map { NSColor($0).cgColor }
      let palette = resolved.count == 1 ? [resolved[0], resolved[0]] : resolved
      let lineWidth = rainbow ? TexterBorderStyle.lineWidth : TexterBorderStyle.normalLineWidth
      if border.lineWidth != lineWidth { previousBounds = .zero }
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      for layer in [base, flow, border, trail] + segments { layer.contentsScale = scale }
      border.lineWidth = lineWidth
      segments.forEach { $0.lineWidth = lineWidth }
      base.colors = palette
      flow.colors = palette
      base.opacity = rainbow ? (animated ? 0.42 : 1) : (animated ? 0.22 : 0.38)
      flow.opacity = rainbow ? 1 : 0.92
      flow.isHidden = !animated
      CATransaction.commit()
      let direction = rainbow ? clockwise : true
      guard self.animated != animated || self.clockwise != direction else { return }
      self.animated = animated
      self.clockwise = direction
      updateAnimation()
    }

    func setVisible(_ visible: Bool) {
      guard self.visible != visible else { return }
      self.visible = visible
      updateAnimation()
    }

    func layout(in bounds: CGRect) {
      guard bounds != previousBounds, bounds.width > 1, bounds.height > 1 else { return }
      previousBounds = bounds
      let geometry = TexterBorderStyle.outline(in: bounds, lineWidth: border.lineWidth)
      length = geometry.length
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      base.frame = bounds
      flow.frame = bounds
      border.frame = base.bounds
      border.path = geometry.path
      trail.frame = flow.bounds
      let step = length * 0.22 / CGFloat(segments.count)
      for segment in segments {
        segment.frame = trail.bounds
        segment.path = geometry.path
        segment.lineDashPattern = [NSNumber(value: Double(step)), NSNumber(value: Double(length - step))]
      }
      CATransaction.commit()
      updateAnimation()
    }

    func stop() { segments.forEach { $0.removeAllAnimations() } }

    private func updateAnimation() {
      stop()
      // Place the brightest segment at the leading end in either direction.
      let step = length * 0.22 / CGFloat(segments.count)
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      for (index, segment) in segments.enumerated() {
        segment.lineDashPhase = (clockwise ? -1 : 1) * CGFloat(index) * step
      }
      CATransaction.commit()
      guard animated, visible, length > 0 else { return }
      let start = CACurrentMediaTime()
      for segment in segments {
        let animation = CABasicAnimation(keyPath: "lineDashPhase")
        animation.fromValue = segment.lineDashPhase
        animation.toValue = segment.lineDashPhase + (clockwise ? -length : length)
        animation.duration = TexterBorderStyle.cycleDuration
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.beginTime = start
        segment.add(animation, forKey: "texter.borderFlow")
      }
    }
  }
}
