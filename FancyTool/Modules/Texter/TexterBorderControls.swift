import SwiftUI

struct TexterBorderControls: View {
  @ObservedObject private var state = AppState.shared
  var fontSize: CGFloat = 11

  var body: some View {
    HStack(spacing: 8) {
      Text("Direction")
        .fixedSize(horizontal: true, vertical: false)
        .frame(minWidth: 48, alignment: .leading)
      Picker("Border Direction", selection: state.$borderClockwise) {
        Text("Counterclockwise Short")
          .accessibilityLabel(Text("Counterclockwise"))
          .tag(false)
        Text("Clockwise Short")
          .accessibilityLabel(Text("Clockwise"))
          .tag(true)
      }
      .labelsHidden().pickerStyle(.segmented).controlSize(.small)
      .fixedSize(horizontal: true, vertical: false)
      .accessibilityIdentifier("texter.borderDirection")
    }
    .frame(height: 22)
    .font(.system(size: fontSize))
  }
}
