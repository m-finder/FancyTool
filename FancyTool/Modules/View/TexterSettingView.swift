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
    ScrollView {
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

          Text(verbatim: "\(state.fontSize)")
            .frame(width: 24, alignment: .trailing)
        }

        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 12) {
          effectToggle("Texter Shimmer", isOn: state.$showShimmer)
            .onChange(of: state.showShimmer) { _, newValue in
              if newValue {
                state.rainbowShimmer = false
              }
            }

          effectToggle("Rainbow Shimmer", isOn: state.$rainbowShimmer)
            .onChange(of: state.rainbowShimmer) { _, newValue in
              if newValue {
                state.showShimmer = false
              }
            }

          effectToggle("Signature Border", isOn: state.$normalBorder)
            .onChange(of: state.normalBorder) { _, newValue in
              if newValue { state.rainbowBorder = false }
            }

          effectToggle("Rainbow Border", isOn: state.$rainbowBorder)
            .onChange(of: state.rainbowBorder) { _, newValue in
              if newValue { state.normalBorder = false }
            }

          effectToggle("Gradient Background", isOn: state.$gradientBackground)
            .help("Add a subtle gradient background.")
            .accessibilityIdentifier("texter.gradientBackground")

          if state.normalBorder || state.rainbowBorder {
            TexterBorderControls(fontSize: 12)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
        TexterPaletteView(columns: 10)
      }
      .padding(.bottom, 12)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .onAppear { fontFamilies = TexterFont.installedFamilies() }
    .onReceive(DistributedNotificationCenter.default().publisher(
      for: Notification.Name(kCTFontManagerRegisteredFontsChangedNotification as String))) { _ in
      fontFamilies = TexterFont.installedFamilies()
    }
  }

  private func effectToggle(_ title: LocalizedStringKey, isOn: Binding<Bool>) -> some View {
    HStack(spacing: 8) {
      Text(title)
        .fixedSize(horizontal: false, vertical: true)
        .frame(minWidth: 48, alignment: .leading)
      Toggle(title, isOn: isOn)
        .labelsHidden()
        .toggleStyle(.switch)
        .controlSize(.small)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var selectedFontFamily: Binding<String> {
    Binding {
      fontFamilies.contains { $0.id == state.fontFamily } ? state.fontFamily : ""
    } set: { state.fontFamily = $0 }
  }
}

#Preview {
  TexterSettingView()
}
