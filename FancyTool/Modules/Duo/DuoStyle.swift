import SwiftUI

/// Small, recognisable Bluetooth mark for the control tile.
struct DuoBluetoothMark: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.midX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.25))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.75))
    path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.25))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.75))
    path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
    return path
  }
}

struct DuoSurface: ViewModifier {
  @Environment(\.colorScheme) private var scheme

  func body(content: Content) -> some View {
    content
      .background {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
          .fill(scheme == .dark ? Color.white.opacity(0.055) : Color.white.opacity(0.5))
      }
      .overlay {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
          .strokeBorder(Color.primary.opacity(scheme == .dark ? 0.07 : 0.055), lineWidth: 0.5)
          .allowsHitTesting(false)
      }
  }
}

/// Keeps native slider keyboard, mouse and accessibility behavior while drawing
/// a compact filled track. The control's frame does not depend on its value.
struct DuoLevelSlider: NSViewRepresentable {
  @Binding var value: Double
  let tint: Color
  let enabled: Bool
  let label: String

  func makeNSView(context: Context) -> NSSlider {
    let slider = NSSlider(value: value, minValue: 0, maxValue: 1,
                          target: context.coordinator, action: #selector(Coordinator.changed(_:)))
    slider.cell = DuoSliderCell()
    slider.target = context.coordinator
    slider.action = #selector(Coordinator.changed(_:))
    slider.minValue = 0
    slider.maxValue = 1
    slider.isContinuous = true
    slider.focusRingType = .none
    return slider
  }

  func updateNSView(_ slider: NSSlider, context: Context) {
    context.coordinator.value = $value
    slider.doubleValue = value.isFinite ? min(1, max(0, value)) : 0
    slider.isEnabled = enabled
    slider.setAccessibilityLabel(label)
    (slider.cell as? DuoSliderCell)?.tint = NSColor(tint)
    slider.needsDisplay = true
  }

  func makeCoordinator() -> Coordinator { Coordinator(value: $value) }

  @MainActor
  final class Coordinator: NSObject {
    var value: Binding<Double>
    init(value: Binding<Double>) { self.value = value }
    @objc func changed(_ sender: NSSlider) { value.wrappedValue = sender.doubleValue }
  }
}

private final class DuoSliderCell: NSSliderCell {
  var tint = NSColor.controlAccentColor
  override func drawBar(inside rect: NSRect, flipped: Bool) {
    let track = NSRect(x: rect.minX, y: rect.midY - 3, width: rect.width, height: 6)
    NSColor.labelColor.withAlphaComponent(isEnabled ? 0.09 : 0.04).setFill()
    NSBezierPath(roundedRect: track, xRadius: 3, yRadius: 3).fill()
    let fraction = CGFloat(min(1, max(0, (doubleValue - minValue) / max(0.001, maxValue - minValue))))
    let fill = NSRect(x: track.minX, y: track.minY, width: track.width * fraction, height: track.height)
    if fill.width > 0 {
      tint.withAlphaComponent(isEnabled ? 0.85 : 0.18).setFill()
      NSBezierPath(roundedRect: fill, xRadius: 3, yRadius: 3).fill()
    }
  }
  override func drawKnob(_ rect: NSRect) {
    guard isEnabled else { return }
    let knob = NSRect(x: rect.midX - 5, y: rect.midY - 5, width: 10, height: 10)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    shadow.shadowBlurRadius = 2
    shadow.shadowOffset = NSSize(width: 0, height: -0.5)
    shadow.set()
    NSColor.white.setFill()
    NSBezierPath(ovalIn: knob).fill()
    NSGraphicsContext.restoreGraphicsState()
    tint.withAlphaComponent(0.25).setStroke()
    let border = NSBezierPath(ovalIn: knob.insetBy(dx: 0.25, dy: 0.25))
    border.lineWidth = 0.5
    border.stroke()
  }
}

