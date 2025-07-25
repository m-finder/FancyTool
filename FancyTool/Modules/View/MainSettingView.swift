//
//  MainSettingView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/24.
//

import SwiftUI
import ServiceManagement

struct MainSettingView: View {
  
  @ObservedObject var state = AppState.shared
  
  var body: some View {
    VStack(alignment: .center, spacing: 0){
      Toggle(
        String(localized: "Launch on Startup"),
        isOn: state.$startUp
      ).onChange(of: state.startUp) {
        if state.startUp {
          if SMAppService.mainApp.status == .enabled {
            try? SMAppService.mainApp.unregister()
          }
          
          try? SMAppService.mainApp.register()
        } else {
          try? SMAppService.mainApp.unregister()
        }
        
      }.toggleStyle(SwitchToggleStyle())
        .font(.system(size: 12))
        .padding()
      
      Button(String(localized: "Quit App")) {
        NSApplication.shared.terminate(nil)
      }.keyboardShortcut("q").frame(
        width: 100,
        height: 40
      ).font(.body)
        .cornerRadius(10)
    }.frame(maxHeight: .infinity, alignment: .top)
  }
}

#Preview {
  MainSettingView()
}
