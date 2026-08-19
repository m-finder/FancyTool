//
//  MainSettingView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/24.
//

import SwiftUI
import AppKit
import ServiceManagement
import Combine

struct MainSettingView: View {
  
  @ObservedObject var state = AppState.shared

  var body: some View {
    
    VStack(alignment: .center, spacing: 0){
      
      HidderSettingView().padding()
      
      RounderSettingView().padding()
      
      TexterSettingView().padding()

      Toggle(
        String(localized: "Launch on Startup"),
        isOn: Binding(
          get: { state.startUp },
          set: { newValue in
            do {
              if newValue {
                if SMAppService.mainApp.status == .enabled {
                  try SMAppService.mainApp.unregister()
                }
                try SMAppService.mainApp.register()
              } else {
                try SMAppService.mainApp.unregister()
              }
              state.startUp = newValue
            } catch {
              let alert = NSAlert()
              alert.alertStyle = .warning
              alert.messageText = String(localized: "Startup Setting Failed")
              alert.informativeText = error.localizedDescription
              alert.addButton(withTitle: String(localized: "OK"))
              alert.runModal()
            }
          }
        )
      )
      .toggleStyle(SwitchToggleStyle())
      .font(.system(size: 12))
      .padding()
      
      
      Button(String(localized: "Quit App")) {
        NSApplication.shared.terminate(nil)
      }
      .keyboardShortcut("q")
      .frame(width: 100, height: 40)
      .font(.body)
      .cornerRadius(10)

      
    }.frame(maxHeight: .infinity, alignment: .top)
    
  }
}
