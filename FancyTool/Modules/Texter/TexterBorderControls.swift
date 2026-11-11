import SwiftUI

struct TexterBorderControls: View {
  @ObservedObject private var state = AppState.shared
  var beforeEditing: () -> Void = {}

  var body: some View {
    VStack(spacing: 8) {
      HStack(spacing: 8) {
        Toggle("Custom Border Colors", isOn: Binding(
          get: { state.useCustomBorderColors },
          set: { enabled in
            if enabled && TexterPalette.customValues(from: state.customBorderColorsData).isEmpty {
              editColors()
            } else {
              state.useCustomBorderColors = enabled
            }
          }
        ))
        .toggleStyle(.switch).controlSize(.mini)
        .accessibilityIdentifier("texter.customBorderColors")
        Spacer(minLength: 0)
        Button(action: editColors) {
          RoundedRectangle(cornerRadius: 4)
            .fill(LinearGradient(colors: TexterPalette.borderColors(customData: state.customBorderColorsData,
                                                                   useCustom: state.useCustomBorderColors),
                                 startPoint: .leading, endPoint: .trailing))
            .frame(width: 36, height: 18)
            .overlay(Image(systemName: "pencil").font(.system(size: 9, weight: .semibold))
              .foregroundStyle(.white).shadow(color: .black.opacity(0.5), radius: 1))
        }.buttonStyle(.plain).help("Custom Border Gradient").accessibilityLabel("Custom Border Gradient")
          .accessibilityIdentifier("texter.editBorderColors")
      }.frame(height: 22)

      HStack(spacing: 8) {
        Text("Direction")
        Spacer(minLength: 0)
        Picker("Border Direction", selection: state.$borderClockwise) {
          Text("Counterclockwise").tag(false)
          Text("Clockwise").tag(true)
        }.labelsHidden().pickerStyle(.segmented).controlSize(.small)
          .frame(width: 176)
          .accessibilityIdentifier("texter.borderDirection")
      }.frame(height: 22)
    }
    .font(.system(size: 11))
  }

  private func editColors() {
    beforeEditing()
    TexterPalette.editCustomBorderColors()
  }
}
