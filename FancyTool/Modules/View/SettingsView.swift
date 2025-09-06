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
        MainSettingView().tabItem { Text("Main") }
        RunnerSettingView().tabItem { Text("Runner") }
        TexterSettingView().tabItem { Text("Texter") }
        PasterSettingView().tabItem { Text("Paster") }
      }
      .frame(maxHeight: .infinity)
      
      CopyrightView().padding(.bottom, 15)
      
    }
    .padding([.top, .leading, .trailing])
  }
}


struct SettingsView_Previews: PreviewProvider {
  static var previews: some View {
    SettingsView()
  }
}
