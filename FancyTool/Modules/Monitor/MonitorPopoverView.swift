import SwiftUI
import SystemInfoKit

struct MonitorPopoverView: View {
  static let panelSize = NSSize(width: 270, height: 450)
  @ObservedObject private var metrics = SystemMetrics.shared

  private var cpu: CPUInfo? { metrics.bundle?.cpuInfo }
  private var mem: MemoryInfo? { metrics.bundle?.memoryInfo }
  private var sto: StorageInfo? { metrics.bundle?.storageInfo }
  private var bat: BatteryInfo? { metrics.bundle?.batteryInfo }
  private var net: NetworkInfo? { metrics.bundle?.networkInfo }

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack {
        Text("Monitor").font(.system(size: 11, weight: .semibold))
        Spacer()
        Text("Last 5 minutes").font(.system(size: 9)).foregroundStyle(.primary.opacity(0.75))
      }
      usageSection(title: "CPU", icon: "cpu", metric: .cpu, color: .blue, details: cpu?.details ?? [])
      usageSection(title: "Memory", icon: "memorychip", metric: .memory, color: .purple, details: mem?.details ?? [])
      storageSection
      if let bat { batterySection(bat) }
      if let net { networkSection(net) }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func usageSection(title: LocalizedStringKey, icon: String, metric: MonitorHistory.Metric,
                            color: Color, details: [String]) -> some View {
    let value = metrics.history.samples.last?.value(for: metric)
    return card(title: title, icon: icon, color: color, value: percentage(value)) {
      MonitorUsageChart(history: metrics.history, metric: metric, color: color)
        .accessibilityLabel(title)
    } details: {
      if value != nil { detailGrid(details) }
    }
  }

  private var storageSection: some View {
    let value = metrics.history.samples.last?.value(for: .storage)
    return card(title: "Storage", icon: "internaldrive", color: .blue,
                value: value.map { String(localized: "\(percentage($0)) used") } ?? "—") {
      if let value {
        ProgressView(value: value, total: 100)
          .progressViewStyle(CapacityBarStyle(color: .blue))
          .accessibilityLabel(Text("Storage"))
      } else {
        waiting
      }
    } details: {
      if value != nil, let sto {
        Text(verbatim: "\(sto.used) / \(sto.total)")
      }
    }
  }

  private func batterySection(_ battery: BatteryInfo) -> some View {
    let charge = battery.percentage.rawValue
    let color: Color = battery.isCharging ? .green : (charge <= 0.1 ? .red : (charge <= 0.2 ? .orange : .blue))
    return card(title: "Battery", icon: battery.icon, color: color,
                value: battery.isInstalled ? percentage(charge * 100) : "—",
                status: battery.isInstalled ? String(localized: battery.isCharging ? "Charging" : "Not charging") : nil) {
      if battery.isInstalled, charge.isFinite, (0...1).contains(charge) {
        ProgressView(value: charge, total: 1)
          .progressViewStyle(CapacityBarStyle(color: color))
          .accessibilityLabel(Text("Battery"))
      } else {
        Text(battery.summary).foregroundStyle(.primary.opacity(0.85))
      }
    } details: {
      if battery.isInstalled { detailGrid(batteryDetails(battery)) }
    }
  }

  private func networkSection(_ network: NetworkInfo) -> some View {
    card(title: "Network", icon: "arrow.up.arrow.down", color: .teal, value: connectionName(network)) {
      MonitorNetworkChart(history: metrics.history).accessibilityLabel(Text("Network"))
    } details: {
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 8) {
          rate(network.details[1], icon: "arrow.up", color: .teal)
          rate(network.details[2], icon: "arrow.down", color: .orange)
        }
        Text(network.details[0])
      }
    }
  }

  private func card(title: LocalizedStringKey, icon: String, color: Color, value: String,
                    status: String? = nil, @ViewBuilder plot: () -> some View,
                    @ViewBuilder details: () -> some View) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 5) {
        Image(systemName: icon).foregroundStyle(color).frame(width: 14)
        Text(title).fontWeight(.medium)
        if let status {
          Text(status).font(.system(size: 8, weight: .medium)).foregroundStyle(color)
            .padding(.horizontal, 4).padding(.vertical, 1)
            .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 3))
        }
        Spacer(minLength: 4)
        Text(value).monospacedDigit().fontWeight(.semibold)
      }
      .font(.system(size: 10))
      .lineLimit(1)
      .minimumScaleFactor(0.85)
      .frame(height: 14)
      plot().frame(maxWidth: .infinity).frame(height: 20)
      details()
        .font(.system(size: 9)).foregroundStyle(.primary.opacity(0.85))
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .frame(maxWidth: .infinity, alignment: .topLeading).frame(height: 22, alignment: .topLeading)
    }
    .padding(5)
    .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
  }

  private func detailGrid(_ lines: [String]) -> some View {
    LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
              alignment: .leading, spacing: 2) {
      ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
        Text(line).help(line)
      }
    }
  }

  private func rate(_ text: String, icon: String, color: Color) -> some View {
    HStack(spacing: 3) {
      Image(systemName: icon).foregroundStyle(color)
      Text(text).monospacedDigit()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var waiting: some View {
    Text("Waiting for samples…").font(.system(size: 9)).foregroundStyle(.primary.opacity(0.75))
  }

  private func percentage(_ value: Double?) -> String {
    PercentText.oneDecimal(value)
  }

  private func connectionName(_ network: NetworkInfo) -> String {
    guard network.hasConnection else { return String(localized: "Disconnected") }
    return switch network.networkInterface {
    case .wifi: "Wi-Fi"
    case .ethernet: "Ethernet"
    case .cellular: String(localized: "Cellular")
    case .loopback: "Loopback"
    case .unknown: "—"
    }
  }

  private func batteryDetails(_ battery: BatteryInfo) -> [String] {
    var details = battery.details
    if !battery.temperature.value.isFinite {
      details[details.count - 1] = String(localized: "Temperature: Unavailable")
    }
    return details
  }
}

private struct CapacityBarStyle: ProgressViewStyle {
  let color: Color

  func makeBody(configuration: Configuration) -> some View {
    let value = configuration.fractionCompleted ?? 0
    let fraction = value.isFinite ? min(1, max(0, value)) : 0
    return Canvas { context, size in
      // The same fine line, translucent area and endpoint as the history plots.
      // A two-point inset keeps the endpoint visible at both 0% and 100%.
      let start: CGFloat = 2
      let width = max(0, size.width - 4)
      let end = start + width * fraction
      let top: CGFloat = 6
      let bottom = size.height - 3

      var guides = Path()
      guides.move(to: CGPoint(x: start, y: bottom))
      guides.addLine(to: CGPoint(x: start + width, y: bottom))
      for tick in 0...4 {
        let x = start + width * CGFloat(tick) / 4
        guides.move(to: CGPoint(x: x, y: 2))
        guides.addLine(to: CGPoint(x: x, y: bottom))
      }
      context.stroke(guides, with: .color(.secondary.opacity(0.2)),
                     style: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))

      context.fill(Path(CGRect(x: start, y: top, width: width * fraction, height: max(0, bottom - top))),
                   with: .color(color.opacity(0.12)))
      var level = Path()
      level.move(to: CGPoint(x: start, y: top))
      level.addLine(to: CGPoint(x: end, y: top))
      context.stroke(level, with: .color(color), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
      context.fill(Path(ellipseIn: CGRect(x: end - 1.75, y: top - 1.75, width: 3.5, height: 3.5)),
                   with: .color(color))
    }
  }
}
