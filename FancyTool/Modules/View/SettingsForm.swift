import SwiftUI

struct SettingsForm<Content: View>: View {
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      content
    }
    .font(.system(size: 12))
    .fontWeight(.regular)
    .frame(width: 270, alignment: .leading)
  }
}

struct SettingsFormRow<Content: View>: View {
  let title: LocalizedStringKey
  @ViewBuilder let content: Content

  init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
    self.title = title
    self.content = content()
  }

  var body: some View {
    HStack(spacing: 8) {
      Text(title)
        .frame(width: 72, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
      content
    }
  }
}

struct SettingsToggle: View {
  let title: LocalizedStringKey
  @Binding var isOn: Bool

  init(_ title: LocalizedStringKey, isOn: Binding<Bool>) {
    self.title = title
    _isOn = isOn
  }

  var body: some View {
    SettingsFormRow(title) {
      Toggle(title, isOn: $isOn)
        .labelsHidden()
        .toggleStyle(.switch)
    }
  }
}
