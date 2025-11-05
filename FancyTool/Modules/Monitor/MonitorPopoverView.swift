//
//  TexterPopoverView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import SwiftUI
import SystemInfoKit

struct MonitorPopoverView: View {
  
  @ObservedObject var state = AppState.shared
  
  // 快速读取，省得每次都写可选链
  private var cpu: CPUInfo? { state.bundle?.cpuInfo }
  private var mem: MemoryInfo? { state.bundle?.memoryInfo }
  private var sto: StorageInfo? { state.bundle?.storageInfo }
  private var bat: BatteryInfo? { state.bundle?.batteryInfo }
  private var net: NetworkInfo? { state.bundle?.networkInfo }
  
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 4) {
        Group {
          makeSection(icon: cpu?.icon ?? "cpu", lines: [cpu?.summary] + (cpu?.details ?? []))
          Divider()
          makeSection(icon: mem?.icon ?? "memorychip", lines: [mem?.summary] + (mem?.details ?? []))
          Divider()
          makeSection(icon: sto?.icon ?? "internaldrive", lines: [sto?.summary] + (sto?.details ?? []))
          Divider()
          makeSection(icon: bat?.icon ?? "battery.50", lines: [bat?.summary] + (bat?.details ?? []))
          Divider()
          makeSection(icon: "arrow.up.arrow.down", lines: [net?.summary] + (net?.details ?? []))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }
  
  @ViewBuilder
  private func makeSection(icon: String?, lines: [String?]) -> some View {
    if let icon = icon, !lines.compactMap({ $0 }).isEmpty {
      VStack(alignment: .leading, spacing: 4) {
        HStack{
          Image(systemName: icon).resizable().aspectRatio(contentMode: .fit).frame(maxWidth: 24, maxHeight: 24)
          VStack(alignment: .leading, spacing: 4) {
            ForEach(lines.compactMap { $0 }, id: \.self) { line in
              Text(line).font(.system(size: 12)).padding(.leading, 4)
            }
          }
        }
      }
    }
  }
}

