//
//  ShotterSettingView.swift
//  FancyTool
//

import SwiftUI
import KeyboardShortcuts

struct ShotterSettingView: View {

  @ObservedObject var state = AppState.shared

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
    }
  }
}

#Preview {
  ShotterSettingView()
}
