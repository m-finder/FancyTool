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
  
  var body: some View {
    SettingsForm {
      SettingsToggle("CPU", isOn: state.$showCpu)
      SettingsToggle("Network", isOn: state.$showNetWork)
      SettingsToggle("Storage", isOn: state.$showStorage)
      SettingsToggle("Memory", isOn: state.$showMemory)
      SettingsToggle("Battery", isOn: state.$showBattery)
      if MonitorStatusLayout(for: state).supportsCompactLayout {
        SettingsToggle("Compact Layout", isOn: state.$monitorCompactLayout)
          .help("Stack monitor modules to save menu-bar space. Turn off to arrange them horizontally.")
          .accessibilityIdentifier("monitor.compactLayout")
      }
    }
  }
}

#Preview {
  MonitorSettingView()
}
