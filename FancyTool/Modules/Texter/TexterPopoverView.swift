import SwiftUI

struct TexterPopoverView: View {
  static let panelSize = NSSize(width: 350, height: 350)

  @ObservedObject var state = AppState.shared
  @FocusState private var isEditing: Bool
  var onSubmit: () -> Void = {}

  private var signatureGradient: LinearGradient {
    LinearGradient(colors: ColorUtil.shared.getColor(index: state.colorIndex),
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

      palette
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

      Text("Texter")
        .font(.system(size: 19, weight: .semibold, design: .rounded))

      Spacer(minLength: 12)

      Text(state.text.isEmpty ? String(localized: "Keep happy.") : state.text)
        .font(Font(TexterFont.resolve(family: state.texterFontFamily, size: 12, systemWeight: .medium)))
        .foregroundStyle(signatureGradient)
        .shimmering(active: state.showShimmer || state.rainbowShimmer, rainbow: state.rainbowShimmer)
        .lineLimit(1)
        .truncationMode(.tail)
        .frame(maxWidth: 128, alignment: .trailing)
        .accessibilityHidden(true)
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
        .font(Font(TexterFont.resolve(family: state.texterFontFamily, size: 13)))
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

  private var palette: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Colorful")
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.secondary)

      LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 26), spacing: 6), count: 10), spacing: 2) {
        ForEach(0..<ColorUtil.shared.getColors().count, id: \.self) { index in
          let selected = state.colorIndex == index
          Button {
            state.colorIndex = index
          } label: {
            Circle()
              .fill(LinearGradient(colors: ColorUtil.shared.getColor(index: index),
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
              .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
              .overlay {
                if selected {
                  Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 1, y: 1)
                }
              }
              .frame(width: 20, height: 20)
              .frame(width: 26, height: 26)
              .overlay(Circle().strokeBorder(.primary.opacity(selected ? 0.6 : 0), lineWidth: 1))
              .contentShape(Circle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel(Text("Colorful") + Text(verbatim: " \(index + 1)"))
          .accessibilityAddTraits(selected ? .isSelected : [])
          .accessibilityIdentifier("texter.color.\(index)")
        }
      }
    }
  }
}
