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
      
      LabeledContent(String(localized: "Hidder size:")) {
        HStack {
          Slider(
            value: Binding(
              get: { Double(state.hidderSize) },
              set: { state.hidderSize = Int($0) }
            ),
            in: 6...12,
            step: 1
          ).frame(width: 150)
          
          Text("\(state.hidderSize)").frame(width: 30)
        }.onChange(of: state.hidderSize) {
          DispatchQueue.main.async {
            Hidder.shared.refresh()
          }
        }
      }
      .padding()
      
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
