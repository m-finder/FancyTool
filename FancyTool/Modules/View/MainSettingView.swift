//
//  MainSettingView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/24.
//

import SwiftUI
import AppKit
import ServiceManagement

struct MainSettingView: View {
  
  @ObservedObject var state = AppState.shared

  var body: some View {
    
    SettingsForm {

      VStack(alignment: .leading, spacing: 6) {
        SettingsFormRow("Appearance") {
          Picker(String(localized: "Appearance"), selection: $state.appAppearance) {
            ForEach(AppAppearance.allCases) { appearance in
              Text(appearance.title).tag(appearance)
            }
          }
          .labelsHidden()
          .pickerStyle(.segmented)
          .controlSize(.small)
        }

        Text("Automatic follows the system appearance.")
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
          .padding(.leading, 80)
      }

      SettingsToggle(
        "Launch on Startup",
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
      
      Button(String(localized: "Quit App")) {
        NSApplication.shared.terminate(nil)
      }
      .keyboardShortcut("q")
      .padding(.leading, 80)
    }
  }
}
