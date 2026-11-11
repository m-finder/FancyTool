import AppKit
import SwiftUI

@MainActor
final class Duo {
  static let shared = Duo()
  private var item: NSStatusItem?
  private var hosting: HostingView?
  private var panel: StatusItemPanel?

  func mount() {
    guard item == nil else { return }
    DuoMetrics.shared.start()
    DuoInputSources.shared.start()
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    self.item = item
    hosting = HostingView(
      view: DuoStatusView().frame(height: 22), item: item,
      target: AppMenuActions.shared, action: #selector(AppMenuActions.duoPopover(_:)),
      fixedSize: DuoStatusGlyph.size
    )
  }

  func unmount() {
    panel?.close(); panel = nil
    hosting?.unmount(); hosting = nil
    if let item { NSStatusBar.system.removeStatusItem(item) }
    self.item = nil
    DuoMetrics.shared.stop()
    DuoInputSources.shared.stop()
  }

  func togglePanel(_ sender: NSStatusBarButton) {
    if panel?.isShown == true { panel?.close(); return }
    DuoBrightness.shared.refresh()
    let maximumHeight = sender.window?.screen.map { $0.visibleFrame.height - 22 } ?? 700
    let content = DuoPopoverView(maximumPanelHeight: maximumHeight) { [weak self] height in
      self?.panel?.setContentSize(NSSize(width: DuoPopoverView.panelSize.width, height: height))
    }
    let panel = StatusItemPanel(size: DuoPopoverView.panelSize, content: content, contentPadding: 12, resizesContent: true)
    panel.onClose = { [weak self] in self?.panel = nil }
    self.panel = panel
    panel.show(relativeTo: sender)
  }

  func closePanel() { panel?.close() }
}

struct DuoStatusView: View {
  @ObservedObject private var metrics = DuoMetrics.shared
  @ObservedObject private var input = DuoInputSources.shared

  var body: some View {
    DuoStatusGlyph(batteryLevel: metrics.battery.map { Double($0.percentage) / 100 },
                   charging: metrics.battery?.charging == true,
                   connected: metrics.wifiConnected,
                   volume: metrics.audio.volume, muted: metrics.audio.muted,
                   inputBadge: input.shortName)
      .help(statusDescription)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Text("Quick Controls"))
      .accessibilityValue(Text(statusDescription))
  }

  private var statusDescription: String {
    let battery = String(localized: "Battery") + ": " + (metrics.battery.map { PercentText.whole(Double($0.percentage)) } ?? "—")
      + (metrics.battery?.charging == true ? " (" + String(localized: "Charging") + ")" : "")
    let sound = String(localized: "Sound") + ": " + (metrics.audio.muted
      ? String(localized: "Mute")
      : metrics.audio.volume.map { PercentText.whole($0 * 100) } ?? "—")
    return [String(localized: "Duo"), battery, sound, input.currentName].joined(separator: " · ")
  }
}

/// Battery and Wi-Fi form the two sides of one emblem. The current input
/// source occupies its center; the lower opening carries the sound mark.
struct DuoStatusGlyph: View {
  let batteryLevel: Double?
  let charging: Bool
  let connected: Bool
  let volume: Double?
  let muted: Bool
  let inputBadge: String
  static let size = NSSize(width: 26, height: 22)

  var body: some View {
    DuoStatusEmblem(batteryLevel: batteryLevel, charging: charging, connected: connected,
                    volume: volume, muted: muted, inputBadge: inputBadge)
      .foregroundStyle(.primary)
      .frame(width: Self.size.width, height: Self.size.height)
      .fixedSize()
  }
}

struct DuoStatusEmblem: View {
  let batteryLevel: Double?
  let charging: Bool
  let connected: Bool
  let volume: Double?
  let muted: Bool
  let inputBadge: String

  private var charge: Double { batteryLevel.flatMap { $0.isFinite ? min(1, max(0, $0)) : nil } ?? 1 }
  private var level: Double { muted ? 0 : (volume.flatMap { $0.isFinite ? min(1, max(0, $0)) : nil } ?? 0) }
  private var filledSoundBars: Int {
    guard volume != nil, !muted, level > 0 else { return 0 }
    return level < 0.33 ? 1 : (level < 0.67 ? 3 : 5)
  }

  var body: some View {
    ZStack {
      ZStack {
        DuoBatteryArc().stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
          .opacity(0.22)
        DuoBatteryArc().trim(from: 0, to: charge)
          .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
      }
      .foregroundStyle(charging ? Color.green : Color.primary)
      .mask {
        Rectangle().overlay {
          if charging {
            Capsule().frame(width: 4.6, height: 6.8).position(DuoEmblemGeometry.chargingPosition)
              .blendMode(.destinationOut)
          }
        }.compositingGroup()
      }
      DuoSignalArcs().stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        .opacity(connected ? 1 : 0.3)
      Text(inputBadge).font(.system(size: 6.6, weight: .semibold, design: .rounded))
        .lineLimit(1).minimumScaleFactor(0.7)
        .frame(width: 8, height: 9).position(x: 12, y: 9.6)
      DuoSoundWaveform(filledBars: filledSoundBars, muted: muted || volume == 0)
        .position(x: 12, y: 18.5)
      if charging {
        DuoChargeBolt().fill(.green)
          .frame(width: 3.4, height: 5.6).position(DuoEmblemGeometry.chargingPosition)
      }
    }
    .frame(width: 24, height: 22)
    .accessibilityHidden(true)
  }
}

private struct DuoSoundWaveform: View {
  let filledBars: Int
  let muted: Bool

  var body: some View {
    Canvas { context, size in
      for index in 0..<5 {
        let filled = filledBars > 0 && abs(index - 2) <= filledBars / 2
        let height = [2.0, 3.3, 4.6, 3.3, 2.0][index]
        let rect = CGRect(x: Double(index) * 2.2, y: (size.height - height) / 2, width: 1.4, height: height)
        if filled {
          context.fill(Path(roundedRect: rect, cornerRadius: 0.7), with: .foreground)
        } else {
          context.stroke(Path(roundedRect: rect.insetBy(dx: 0.2, dy: 0.2), cornerRadius: 0.5),
                         with: .foreground, lineWidth: 0.4)
        }
      }
      if muted {
        var slash = Path()
        slash.move(to: CGPoint(x: 1.6, y: 5.8))
        slash.addLine(to: CGPoint(x: 8.6, y: 0.4))
        context.blendMode = .destinationOut
        context.stroke(slash, with: .color(.white), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        context.blendMode = .normal
        context.stroke(slash, with: .foreground, style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
      }
    }
    .frame(width: 10.2, height: 6.2)
  }
}

private struct DuoChargeBolt: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: 0.72, y: 0))
    path.addLine(to: CGPoint(x: 0, y: 0.55))
    path.addLine(to: CGPoint(x: 0.42, y: 0.55))
    path.addLine(to: CGPoint(x: 0.24, y: 1))
    path.addLine(to: CGPoint(x: 1, y: 0.39))
    path.addLine(to: CGPoint(x: 0.57, y: 0.39))
    path.closeSubpath()
    return path.applying(CGAffineTransform(scaleX: rect.width, y: rect.height))
  }
}

/// The left half is a battery gauge; the right half carries Wi-Fi status.
/// The Wi-Fi segments share the battery gauge's circle and grow progressively
/// longer from top to bottom.
private enum DuoEmblemGeometry {
  static let center = CGPoint(x: 12, y: 10.6)
  static let radius = 9.1
  static let batteryStart = Angle.degrees(140)
  static let batteryEnd = Angle.degrees(250)
  static var chargingPosition: CGPoint {
    let midpoint = (batteryStart.radians + batteryEnd.radians) / 2
    return CGPoint(x: center.x + radius * cos(midpoint), y: center.y + radius * sin(midpoint))
  }
}

private struct DuoBatteryArc: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.addArc(center: DuoEmblemGeometry.center, radius: DuoEmblemGeometry.radius,
                startAngle: DuoEmblemGeometry.batteryStart, endAngle: DuoEmblemGeometry.batteryEnd, clockwise: false)
    return path.applying(CGAffineTransform(scaleX: rect.width / 24, y: rect.height / 22))
  }
}

private struct DuoSignalArcs: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    let center = DuoEmblemGeometry.center
    let radius = DuoEmblemGeometry.radius
    for (start, end) in [(-70.0, -52.0), (-36.0, -10.0), (6.0, 40.0)] {
      let angle = Angle.degrees(start)
      path.move(to: CGPoint(x: center.x + radius * cos(angle.radians), y: center.y + radius * sin(angle.radians)))
      path.addArc(center: center, radius: radius,
                 startAngle: .degrees(start), endAngle: .degrees(end), clockwise: false)
    }
    return path.applying(CGAffineTransform(scaleX: rect.width / 24, y: rect.height / 22))
  }
}
