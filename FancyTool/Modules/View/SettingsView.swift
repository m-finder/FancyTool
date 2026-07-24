//
//  SettingsView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import SwiftUI

struct SettingsView: View {
  var body: some View {
    VStack(alignment: .center, spacing: 0) {
      
      TabView {
        MainSettingView().tabItem { Text("Universal") }
        RunnerSettingView().tabItem { Text("Runner") }
        PasterSettingView().tabItem { Text("Paster") }
        MonitorSettingView().tabItem { Text("Monitor") }
      }
      
      CopyrightView().padding(.bottom, 15)
      
    }
    .padding(.top, 20)
  }
}


struct SettingsView_Previews: PreviewProvider {
  static var previews: some View {
    SettingsView()
  }
}
