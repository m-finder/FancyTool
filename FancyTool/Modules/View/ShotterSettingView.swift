//
//  ShotterSettingView.swift
//  FancyTool
//

import SwiftUI
import KeyboardShortcuts

struct ShotterSettingView: View {

  @ObservedObject var state = AppState.shared
  @ObservedObject private var shortcut = ShotterShortcut.shared

  var body: some View {
    SettingsForm {
      SettingsToggle("Shotter", isOn: state.$showShotter)
        .onChange(of: state.showShotter) { _, newValue in
          if newValue {
            Shotter.shared.mount()
          } else {
            Shotter.shared.unmount()
          }
        }

      SettingsFormRow("Shortcut:") {
        KeyboardShortcuts.Recorder(for: .shotter)
      }

      if shortcut.registrationError != nil {
        Text("The screenshot shortcut is unavailable. Close the other screenshot tool, then turn Shotter off and on to retry.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}

#Preview {
  ShotterSettingView()
}
