//
//  MonitorCpuView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/10/30.
//

import SwiftUI
import SystemInfoKit

struct MonitorView: View {
  
  @ObservedObject private var state = AppState.shared
  @ObservedObject private var metrics = SystemMetrics.shared
  
  // 快速读取，省得每次都写可选链
  private var cpu: CPUInfo? { metrics.bundle?.cpuInfo }
  private var mem: MemoryInfo? { metrics.bundle?.memoryInfo }
  private var sto: StorageInfo? { metrics.bundle?.storageInfo }
  private var bat: BatteryInfo? { metrics.bundle?.batteryInfo }
  private var net: NetworkInfo? { metrics.bundle?.networkInfo }
  
  
  private var upload: String {
    net?.upload.description ?? "-"
  }
  
  private var download: String {
    net?.download.description ?? "-"
  }
  
  
  

  private func icon(_ name: String, size: CGSize = CGSize(width: 14, height: 8)) -> some View {
    MonitorStatusIcon(name: name, size: size)
      .fixedSize()
  }

  private struct Metric: Identifiable {
    let id: String
    let symbol: String
    let value: Double?
  }

  private var enabledMetrics: [Metric] {
    var result: [Metric] = []
    if state.showCpu { result.append(Metric(id: String(localized: "CPU"), symbol: "cpu", value: cpu?.percentage.value)) }
    if state.showMemory { result.append(Metric(id: String(localized: "Memory"), symbol: "memorychip", value: mem?.percentage.value)) }
    if state.showStorage { result.append(Metric(id: String(localized: "Storage"), symbol: "internaldrive", value: sto?.percentage.value)) }
    if state.showBattery { result.append(Metric(id: String(localized: "Battery"), symbol: bat?.icon ?? "battery.50percent", value: bat?.percentage.value)) }
    return result
  }

  var body: some View {
    let values = enabledMetrics
    let layout = MonitorStatusLayout(for: state)
    HStack(spacing: layout.spacing) {
      if layout.pairsMetrics {
        ForEach(0..<((values.count + 1) / 2), id: \.self) { column in
          let index = column * 2
          if index + 1 < values.count {
            VStack(spacing: 0) {
              metricRow(values[index], layout: layout)
              metricRow(values[index + 1], layout: layout)
            }.frame(width: layout.metricWidth, height: MonitorStatusLayout.height)
          } else {
            standaloneMetric(values[index], layout: layout)
          }
        }
      } else {
        ForEach(values) { metricRow($0, layout: layout) }
      }
      if state.showNetWork {
        // Leading-aligned values stay beside the arrows at every digit count.
        // Fixed slots and a separate inset preserve the gap from other metrics.
        Grid(alignment: .leading, horizontalSpacing: 1, verticalSpacing: 0) {
          networkRow(net?.upload.byteCount, arrow: "arrow.up", layout: layout)
          networkRow(net?.download.byteCount, arrow: "arrow.down", layout: layout)
        }
        .padding(.leading, layout.networkLeadingPadding)
        .frame(width: layout.networkWidth, height: MonitorStatusLayout.height, alignment: .leading)
        .help(Text(verbatim: "↑ \(upload)/s  ↓ \(download)/s"))
      }
    }
    .frame(
      width: layout.contentWidth,
      height: MonitorStatusLayout.height,
      alignment: .leading
    )
    .fixedSize()
  }

  private func metricRow(_ metric: Metric, layout: MonitorStatusLayout) -> some View {
    HStack(spacing: layout.metricInnerSpacing) {
      icon(metric.symbol, size: layout.metricIconSize)
      metricValue(metric, size: layout.metricFontSize)
        .frame(width: layout.metricValueWidth, alignment: .trailing)
    }
    .frame(width: layout.metricWidth, height: layout.pairsMetrics ? layout.stackedRowHeight : MonitorStatusLayout.height)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(metric.id))
    .accessibilityValue(Text(PercentText.oneDecimal(metric.value)))
    .help(metric.id)
  }

  private func standaloneMetric(_ metric: Metric, layout: MonitorStatusLayout) -> some View {
    VStack(spacing: 0) {
      icon(metric.symbol, size: layout.metricIconSize)
        .frame(height: layout.stackedRowHeight)
      metricValue(metric, size: layout.metricFontSize).frame(height: layout.stackedRowHeight)
    }
    .frame(width: layout.standaloneWidth, height: MonitorStatusLayout.height)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(metric.id))
    .accessibilityValue(Text(PercentText.oneDecimal(metric.value)))
    .help(metric.id)
  }

  private func metricValue(_ metric: Metric, size: CGFloat) -> some View {
    Text(PercentText.whole(metric.value.map { min(100, max(0, $0)) }))
      .font(.system(size: size, weight: .medium))
      .monospacedDigit()
      .lineLimit(1)
      .fixedSize()
  }

  private func networkRow(_ bytes: Double?, arrow: String, layout: MonitorStatusLayout) -> some View {
    GridRow {
      icon(arrow, size: layout.networkArrowSize)
        .frame(width: layout.networkArrowWidth, height: layout.stackedRowHeight)
      Text(MonitorRateFormatter.compact(bytes))
        .font(.system(size: layout.networkFontSize, weight: .medium))
        .monospacedDigit()
        .lineLimit(1)
        .fixedSize()
        .frame(width: layout.networkValueWidth, height: layout.stackedRowHeight,
               alignment: .leading)
    }
  }

}

/// Draw compact monochrome template symbols at the display's backing scale.
private struct MonitorStatusIcon: NSViewRepresentable {
  let name: String
  let size: CGSize

  func makeNSView(context: Context) -> MonitorSymbolImageView {
    let view = MonitorSymbolImageView()
    view.imageScaling = .scaleProportionallyUpOrDown
    return view
  }

  func updateNSView(_ view: MonitorSymbolImageView, context: Context) {
    if view.symbolName != name {
      let configuration = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
      view.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(configuration)
      view.image?.isTemplate = true
      view.symbolName = name
    }
    let tint = NSColor.labelColor
    if view.contentTintColor?.isEqual(tint) != true {
      view.contentTintColor = tint
    }
  }

  func sizeThatFits(_ proposal: ProposedViewSize, nsView: MonitorSymbolImageView,
                   context: Context) -> CGSize? {
    size
  }
}

private final class MonitorSymbolImageView: NSImageView {
  var symbolName: String?
  override var allowsVibrancy: Bool { false }
}

#Preview {
  MonitorView()
}
