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
  @State private var hasAccessibilityPermission = AXIsProcessTrusted()
  
  var body: some View {
    
    SettingsForm {

        SettingsFormRow("Number of records:") {
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

        Text("History is limited to 256 MB.")
          .font(.caption)
          .foregroundStyle(.secondary)

        SettingsFormRow("Shortcut:") {
          KeyboardShortcuts.Recorder(for: .paster)
        }

        SettingsToggle("Auto Paste", isOn: $state.autoPaste)
          .onChange(of: state.autoPaste) { _, newValue in
            if newValue {
              hasAccessibilityPermission = Paster.shared.requestAccessibilityPermission()
            }
          }

        if state.autoPaste && !hasAccessibilityPermission {
          Text("Please enable permissions for this app in System Settings > Security & Privacy > Privacy > Accessibility to allow paste operations.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          Button("Open Accessibility Settings") {
            hasAccessibilityPermission = Paster.shared.requestAccessibilityPermission()
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
              NSWorkspace.shared.open(url)
            }
          }
        }
    }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
      hasAccessibilityPermission = AXIsProcessTrusted()
    }
  }
}

#Preview {
  PasterSettingView()
}
