//
//  MonitorCpuView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/10/30.
//

import SwiftUI
import SystemInfoKit

struct MonitorView: View {
  
  @ObservedObject var appState = AppState.shared
  
  @ObservedObject var state = AppState.shared
  
  // 快速读取，省得每次都写可选链
  private var cpu: CPUInfo? { state.bundle?.cpuInfo }
  private var mem: MemoryInfo? { state.bundle?.memoryInfo }
  private var sto: StorageInfo? { state.bundle?.storageInfo }
  private var bat: BatteryInfo? { state.bundle?.batteryInfo }
  private var net: NetworkInfo? { state.bundle?.networkInfo }
  
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
    AppState.shared.bundle?.memoryInfo?.percentage.value ?? 0
  }
  
  private var storage: Double {
    sto?.percentage.value ?? 0
  }
  
  var body: some View {
    HStack(spacing: 4) {
      if AppState.shared.showCpu {
        HStack(alignment: .center, spacing: 1) {
          Image(systemName: cpu?.icon ?? "cpu").resizable().frame(width: 12, height: 12)
          Text(String(format: "%.1f%%", usage)).frame(width: 35).offset(y: 0.5)
        }.font(.caption).frame(width: 55)
      }
      
      
      if AppState.shared.showMemory {
        HStack(alignment: .center, spacing: 1) {
          Image(systemName: mem?.icon ?? "memorychip").resizable().frame(width: 14, height: 8)
          Text(String(format: "%.1f%%", memory)).frame(width: 35).offset(y: 0.5)
        }.font(.caption).frame(width: 55)
      }
      
      if AppState.shared.showStorage {
        HStack(alignment: .center, spacing: 1) {
          Image(systemName: sto?.icon ?? "internaldrive").resizable().frame(width: 14, height: 8)
          Text(String(format: "%.1f%%", storage)).frame(width: 35).offset(y: 0.5)
        }.font(.caption).frame(width: 55)
      }
      
      
      if AppState.shared.showBattery {
        HStack(alignment: .center, spacing: 1) {
          Image(systemName: bat?.icon ?? "battery.50").resizable().frame(width: 14, height: 8)
          Text(String(format: "%.0f%%", battery)).frame(width: 35).offset(y: 0.5)
        }.font(.caption).frame(width: 55)
      }
      
      if AppState.shared.showNetWork {
        HStack(alignment: .center, spacing: 1) {
          Image(systemName: "arrow.up.arrow.down").resizable().frame(width: 10, height: 8)
          
          VStack(alignment: .trailing, spacing: -1) {
            HStack(spacing: 0){
              Text(String(format: "%@", upload)).frame(width: 40).font(.system(size: 8))
            }
            
            HStack(spacing: 0){
              Text(String(format: "%@", download)).frame(width: 40).font(.system(size: 8))
            }
          }
        }
      }
 
    }
  }
}

#Preview {
  MonitorView()
}
