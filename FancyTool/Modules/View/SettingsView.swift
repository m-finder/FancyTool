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
        MainSettingView().tabItem { Text(String(localized: "Universal")) }
        RunnerSettingView().tabItem { Text(String(localized: "Runner")) }
        PasterSettingView().tabItem { Text(String(localized: "Paster")) }
        MonitorSettingView().tabItem { Text(String(localized: "Monitor")) }
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
