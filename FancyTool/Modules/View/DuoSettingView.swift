import SwiftUI

struct DuoSettingView: View {
  @ObservedObject private var state = AppState.shared

  var body: some View {
    SettingsForm {
      SettingsToggle("Show in Menu Bar", isOn: Binding(
        get: { state.showDuo },
        set: { value in
          state.showDuo = value
          if value { Duo.shared.mount() } else { Duo.shared.unmount() }
          AppMenu.shared.refreshFeatureStates()
        }
      ))
    }
  }
}
