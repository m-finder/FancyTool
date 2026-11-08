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
  
  private var usage: Double {
    cpu?.percentage.value ?? 0
  }
  
  private var upload: String {
    net?.upload.description ?? "-"
  }
  
  private var download: String {
    net?.download.description ?? "-"
  }
  
  private var battery: Double {
    bat?.percentage.value ?? 0
  }
  
  private var memory: Double {
    mem?.percentage.value ?? 0
  }
  
  private var storage: Double {
    sto?.percentage.value ?? 0
  }

  private func iconColor(_ color: Color) -> Color {
    state.monitorColoredIcons ? color : .primary
  }

  private var batteryColor: Color {
    if bat?.isCharging == true { return .green }
    guard let charge = bat?.percentage.rawValue else { return .blue }
    return charge <= 0.1 ? .red : (charge <= 0.2 ? .orange : .blue)
  }

  private func icon(_ name: String, color: Color, size: CGSize = CGSize(width: 14, height: 8)) -> some View {
    MonitorStatusIcon(name: name, color: iconColor(color), size: size)
      .fixedSize()
  }

  private func percentage(_ value: Double, decimalPlaces: Int = 1) -> some View {
    Text(String(format: "%.*f%%", decimalPlaces, value))
      .font(.system(size: 10))
      .monospacedDigit()
      .fixedSize()
  }

  var body: some View {
    HStack(spacing: 4) {
      if state.showCpu {
        HStack(spacing: 1) {
          icon(cpu?.icon ?? "cpu", color: .blue, size: CGSize(width: 12, height: 12))
          percentage(usage)
        }
      }

      if state.showMemory {
        HStack(spacing: 1) {
          icon(mem?.icon ?? "memorychip", color: .purple)
          percentage(memory)
        }
      }

      if state.showStorage {
        HStack(spacing: 1) {
          icon(sto?.icon ?? "internaldrive", color: .blue)
          percentage(storage)
        }
      }

      if state.showBattery {
        HStack(spacing: 1) {
          icon(bat?.icon ?? "battery.50percent", color: batteryColor)
          percentage(battery, decimalPlaces: 0)
        }
      }

      if state.showNetWork {
        HStack(spacing: 1) {
          icon("arrow.up.arrow.down", color: .teal, size: CGSize(width: 10, height: 8))
          VStack(alignment: .leading, spacing: 0) {
            Text(upload)
            Text(download)
          }
          .font(.system(size: 7.5))
          .monospacedDigit()
          .fixedSize()
          .frame(minWidth: 36, alignment: .leading)
        }
      }
    }
    .fixedSize()
  }
}

/// Draw compact symbols without the menu bar's vibrancy blending
/// washing out colored strokes. AppKit handles the display's backing scale.
private struct MonitorStatusIcon: NSViewRepresentable {
  let name: String
  let color: Color
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
    let tint = NSColor(color)
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
