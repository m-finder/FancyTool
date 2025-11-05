//
//  PasterSettingView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/25.
//

import SwiftUI
import KeyboardShortcuts

struct MonitorSettingView: View {
  
  @ObservedObject var state = AppState.shared
  
  // 抽取重复的Toggle配置为自定义组件
  private func MonitorToggle(
    title: LocalizedStringKey,
    isOn: Binding<Bool>
  ) -> some View {
    Toggle(title, isOn: isOn)
      .onChange(of: isOn.wrappedValue) {
        Monitor.shared.popover.close()
        Monitor.shared.mount()
        // 确保监控总开关开启
        if !state.showMonitor {
          state.showMonitor = true
        }
      }
      .toggleStyle(SwitchToggleStyle())
      .font(.system(size: 12))
      .padding()
  }
  
  var body: some View {
    VStack(alignment: .center, spacing: 0) {
      // cpu 和 网络开关
      HStack {
        MonitorToggle(title: "CPU", isOn: state.$showCpu)
        MonitorToggle(title: "Network", isOn: state.$showNetWork)
      }
      
      // 存储和内存开关
      HStack {
        MonitorToggle(title: "Storage", isOn: state.$showStorage)
        MonitorToggle(title: "Memory", isOn: state.$showMemory)
      }
      
      // 电池开关
      HStack {
        MonitorToggle(title: "Battery", isOn: state.$showBattery)
      }
    }
    .frame(maxHeight: .infinity, alignment: .top)
    .font(.system(size: 12))
  }
}

#Preview {
  MonitorSettingView()
}
