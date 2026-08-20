//
//  ShotterSettingView.swift
//  FancyTool
//

import SwiftUI
import KeyboardShortcuts

struct ShotterSettingView: View {

  @ObservedObject var state = AppState.shared

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Toggle(String(localized: "Shotter"), isOn: state.$showShotter)
        .onChange(of: state.showShotter) { _, newValue in
          if newValue {
            Shotter.shared.mount()
          } else {
            Shotter.shared.unmount()
          }
        }
        .toggleStyle(SwitchToggleStyle())

      KeyboardShortcuts.Recorder(
        String(localized: "Shortcut:"),
        name: .shotter
      )
    }
    .font(.system(size: 12))
  }
}

#Preview {
  ShotterSettingView()
}
