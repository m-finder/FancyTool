//
//  MonitorCpuView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/10/30.
//

import SwiftUI
import SystemInfoKit

struct MonitorView: View {
  
  let state: MonitorStatusSelection
  let readings: MonitorStatusReadings

  private var upload: String {
    MonitorByteFormatter.string(readings.upload)
  }
  
  private var download: String {
    MonitorByteFormatter.string(readings.download)
  }
  
  
  

  private func icon(_ name: String, size: CGSize = CGSize(width: 14, height: 8)) -> some View {
    Image(nsImage: MonitorStatusSymbols.image(named: name))
      .resizable()
      .scaledToFit()
      .frame(width: size.width, height: size.height)
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
    let layout = state.layout
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

@MainActor
private enum MonitorStatusSymbols {
  static var images: [String: NSImage] = [:]

  static func image(named name: String) -> NSImage {
    if let image = images[name] { return image }
    let configuration = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
    let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
      .withSymbolConfiguration(configuration) ?? NSImage()
    image.isTemplate = true
    images[name] = image
    return image
  }
}

struct MonitorStatusSelection: Equatable {
  let showCpu: Bool
  let showMemory: Bool
  let showStorage: Bool
  let showBattery: Bool
  let showNetWork: Bool
  let compact: Bool

  @MainActor
  init(_ state: AppState = .shared) {
    showCpu = state.showCpu
    showMemory = state.showMemory
    showStorage = state.showStorage
    showBattery = state.showBattery
    showNetWork = state.showNetWork
    compact = state.monitorCompactLayout
  }

  var layout: MonitorStatusLayout {
    MonitorStatusLayout(metricCount: [showCpu, showMemory, showStorage, showBattery].filter { $0 }.count,
                        showsNetwork: showNetWork, compact: compact)
  }

  func readings(_ bundle: SystemInfoBundle?) -> MonitorStatusReadings {
    MonitorStatusReadings(bundle, cpu: showCpu, memory: showMemory, storage: showStorage,
                          battery: showBattery, network: showNetWork)
  }
}

#Preview {
  MonitorView(state: MonitorStatusSelection(), readings: MonitorStatusSelection().readings(nil))
}
