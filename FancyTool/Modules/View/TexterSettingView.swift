//
//  TexterSettingView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2026/7/25.
//

import SwiftUI
import CoreText

struct TexterSettingView: View {
  
  @ObservedObject var state = AppState.shared
  @State private var fontFamilies: [TexterFont.Family] = []
  
  var body: some View {
    SettingsForm {
      SettingsFormRow("Font:") {
        Picker("Font:", selection: selectedFontFamily) {
          Text("System Default").tag("")
          Divider()
          ForEach(fontFamilies) { family in
            Text(verbatim: family.displayName).tag(family.id)
          }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("texter.fontFamily")
      }

      SettingsFormRow("Font size:") {
        Slider(
          value: Binding(
            get: { Double(state.fontSize) },
            set: { state.fontSize = Int($0) }
          ),
          in: 12...16,
          step: 1
        )
        .frame(width: 150)
        
        Text("\(state.fontSize)")
          .frame(width: 24, alignment: .trailing)
      }

      SettingsToggle("Texter Shimmer", isOn: state.$showShimmer)
        .onChange(of: state.showShimmer) { _, newValue in
          if newValue {
            state.rainbowShimmer = false
          }
        }

      SettingsToggle("Rainbow Shimmer", isOn: state.$rainbowShimmer)
        .onChange(of: state.rainbowShimmer) { _, newValue in
          if newValue {
            state.showShimmer = false
          }
        }
    }
    .onAppear { fontFamilies = TexterFont.installedFamilies() }
    .onReceive(DistributedNotificationCenter.default().publisher(
      for: Notification.Name(kCTFontManagerRegisteredFontsChangedNotification as String))) { _ in
      fontFamilies = TexterFont.installedFamilies()
    }
  }

  private var selectedFontFamily: Binding<String> {
    Binding {
      fontFamilies.contains { $0.id == state.texterFontFamily } ? state.texterFontFamily : ""
    } set: { state.texterFontFamily = $0 }
  }
}

#Preview {
  TexterSettingView()
}
