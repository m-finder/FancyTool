//
//  PasterSettingView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/25.
//

import SwiftUI
import KeyboardShortcuts

struct PasterSettingView: View {
  
  @ObservedObject var state = AppState.shared
  
  var body: some View {
    
    VStack(alignment: .center, spacing: 4) {

        LabeledContent(String(localized: "Number of records:")){
          TextField(
            "",
            value: $state.historyCount,
            format: .number
          )
          .onChange(of: state.historyCount) { _, newValue in
            state.historyCount = min(200, max(1, newValue))
            Paster.shared.trimToLimit()
          }
          .frame(width: 150)
          .textFieldStyle(.roundedBorder)
        }
        .padding(.vertical, 8)

        KeyboardShortcuts.Recorder("Shortcut:", name: .paster)
          .padding(.vertical, 8)

        Toggle("Auto Paste", isOn: $state.autoPaste)
          .onChange(of: state.autoPaste) { _, newValue in
            if newValue {
              let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
              if !AXIsProcessTrustedWithOptions(options) {
                let alert = NSAlert()
                alert.messageText = String(localized: "Need Accessibility Permissions")
                alert.informativeText = String(localized: "Auto Paste requires Accessibility permission. Enable it in System Settings > Privacy & Security > Accessibility, then toggle Auto Paste again.")
                alert.addButton(withTitle: String(localized: "OK"))
                alert.runModal()
                state.autoPaste = false
              }
            }
          }
          .padding(.vertical, 8)
    }
    .font(.system(size: 12))
  }
}

#Preview {
  PasterSettingView()
}
