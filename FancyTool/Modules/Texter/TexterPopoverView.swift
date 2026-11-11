import SwiftUI

struct TexterPopoverView: View {
  static let panelSize = NSSize(width: 350, height: 460)

  @ObservedObject var state = AppState.shared
  @FocusState private var isEditing: Bool
  var onSubmit: () -> Void = {}

  private var signatureGradient: LinearGradient {
    LinearGradient(colors: TexterPalette.colors(index: state.colorIndex, customData: state.customColorsData),
                   startPoint: .topLeading, endPoint: .bottomTrailing)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      header
      textInput

      HStack(spacing: 8) {
        animationToggle("Texter Shimmer", isOn: shimmerBinding(rainbow: false), tint: .accentColor)
          .accessibilityIdentifier("texter.shimmer")
        animationToggle("Rainbow Shimmer", isOn: shimmerBinding(rainbow: true), tint: .purple)
          .accessibilityIdentifier("texter.rainbow")
      }

      HStack(spacing: 8) {
        animationToggle("Rounded Border", isOn: borderBinding(rainbow: false), tint: .accentColor)
          .accessibilityIdentifier("texter.border")
        animationToggle("Rainbow Border", isOn: borderBinding(rainbow: true), tint: .purple)
          .accessibilityIdentifier("texter.rainbowBorder")
      }

      TexterBorderControls(beforeEditing: onSubmit)
      TexterPaletteView(beforeEditing: onSubmit)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
  }

  private var header: some View {
    HStack(spacing: 10) {
      Image("default")
        .resizable()
        .scaledToFit()
        .frame(width: 26, height: 26)
        .frame(width: 34, height: 34)
        .background(signatureGradient.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(signatureGradient.opacity(0.22)))
        .accessibilityHidden(true)

      Text("Texter").font(.system(size: 19, weight: .semibold, design: .rounded))
    }
    .frame(height: 34)
  }

  private var textInput: some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack {
        Text("MenuBar Text")
        Spacer()
        Text(verbatim: "\(state.text.count)/30")
          .monospacedDigit()
      }
      .font(.system(size: 10, weight: .medium))
      .foregroundStyle(.secondary)

      TextField(String(localized: "Input something"), text: state.$text)
        .font(Font(TexterFont.resolve(family: state.fontFamily, size: 13)))
        .textFieldStyle(.plain)
        .focused($isEditing)
        .onSubmit(onSubmit)
        .onChange(of: state.text) {
          if state.text.count > 30 { state.text = String(state.text.prefix(30)) }
        }
        .padding(.horizontal, 11)
        .frame(height: 34)
        .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10)
          .strokeBorder(isEditing ? Color.accentColor.opacity(0.7) : .primary.opacity(0.12), lineWidth: 1))
        .shadow(color: .accentColor.opacity(isEditing ? 0.08 : 0), radius: 4)
        .accessibilityIdentifier("texter.input")
    }
  }

  private func shimmerBinding(rainbow: Bool) -> Binding<Bool> {
    Binding {
      rainbow ? state.rainbowShimmer : state.showShimmer
    } set: { enabled in
      if rainbow {
        if enabled { state.showShimmer = false }
        state.rainbowShimmer = enabled
      } else {
        if enabled { state.rainbowShimmer = false }
        state.showShimmer = enabled
      }
    }
  }

  private func animationToggle(_ title: LocalizedStringKey, isOn: Binding<Bool>, tint: Color) -> some View {
    Toggle(isOn: isOn) {
      Text(title)
        .font(.system(size: 11, weight: .medium))
        .lineLimit(1)
        .minimumScaleFactor(0.85)
    }
    .toggleStyle(.switch)
    .controlSize(.mini)
    .tint(tint)
    .padding(.horizontal, 10)
    .frame(maxWidth: .infinity)
    .frame(height: 40)
    .background(isOn.wrappedValue ? tint.opacity(0.08) : .primary.opacity(0.035),
                in: RoundedRectangle(cornerRadius: 10))
    .overlay(RoundedRectangle(cornerRadius: 10)
      .strokeBorder(isOn.wrappedValue ? tint.opacity(0.22) : .primary.opacity(0.06)))
  }

  private func borderBinding(rainbow: Bool) -> Binding<Bool> {
    Binding {
      rainbow ? state.rainbowBorder : state.normalBorder
    } set: { enabled in
      if rainbow {
        if enabled { state.normalBorder = false }
        state.rainbowBorder = enabled
      } else {
        if enabled { state.rainbowBorder = false }
        state.normalBorder = enabled
      }
    }
  }
}
