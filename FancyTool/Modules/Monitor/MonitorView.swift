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
  @State private var readings = MonitorStatusReadings(nil,
    cpu: false, memory: false, storage: false, battery: false, network: false)

  private var selection: [Bool] {
    [state.showCpu, state.showMemory, state.showStorage, state.showBattery, state.showNetWork]
  }

  private func updateReadings(_ bundle: SystemInfoBundle?) {
    let next = MonitorStatusReadings(bundle, cpu: state.showCpu, memory: state.showMemory,
      storage: state.showStorage, battery: state.showBattery, network: state.showNetWork)
    if next != readings { readings = next }
  }
  
  
  private var upload: String {
    MonitorByteFormatter.string(readings.upload)
  }
  
  private var download: String {
    MonitorByteFormatter.string(readings.download)
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
    if state.showCpu { result.append(Metric(id: String(localized: "CPU"), symbol: "cpu", value: readings.cpu)) }
    if state.showMemory { result.append(Metric(id: String(localized: "Memory"), symbol: "memorychip", value: readings.memory)) }
    if state.showStorage { result.append(Metric(id: String(localized: "Storage"), symbol: "internaldrive", value: readings.storage)) }
    if state.showBattery { result.append(Metric(id: String(localized: "Battery"), symbol: readings.batterySymbol, value: readings.battery)) }
    return result
  }

  var body: some View {
    let values = enabledMetrics
    let layout = MonitorStatusLayout(for: state)
    let upload = state.showNetWork ? upload : ""
    let download = state.showNetWork ? download : ""
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
        if layout.isNetworkOnly {
          HStack(spacing: 1) {
            icon("arrow.up.arrow.down", size: CGSize(width: 10, height: 8))
            VStack(alignment: .trailing, spacing: -1) {
              Text(upload).frame(width: 40)
              Text(download).frame(width: 40)
            }
            .font(.system(size: 8))
            .monospacedDigit()
            .lineLimit(1)
          }
          .frame(width: layout.networkWidth, height: MonitorStatusLayout.height)
          .help(Text(verbatim: "↑ \(upload)/s  ↓ \(download)/s"))
        } else {
          // Leading-aligned values stay beside the arrows at every digit count.
          // Fixed slots and a separate inset preserve the gap from other metrics.
          Grid(alignment: .leading, horizontalSpacing: 1, verticalSpacing: 0) {
            networkRow(readings.upload, arrow: "arrow.up", layout: layout)
            networkRow(readings.download, arrow: "arrow.down", layout: layout)
          }
          .padding(.leading, layout.networkLeadingPadding)
          .frame(width: layout.networkWidth, height: MonitorStatusLayout.height, alignment: .leading)
          .help(Text(verbatim: "↑ \(upload)/s  ↓ \(download)/s"))
        }
      }
    }
    .frame(
      width: layout.contentWidth,
      height: MonitorStatusLayout.height,
      alignment: .leading
    )
    .fixedSize()
    .onReceive(SystemMetrics.shared.$bundle) { updateReadings($0) }
    .onChange(of: selection, initial: true) { updateReadings(SystemMetrics.shared.bundle) }
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
