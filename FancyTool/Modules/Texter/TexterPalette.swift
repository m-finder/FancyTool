import AppKit
import SwiftUI

/// Texter owns its custom slot; other modules keep their existing preset palette.
@MainActor
enum TexterPalette {
  static var customIndex: Int { ColorUtil.shared.getColors().count - 1 }

  static func customValues(from data: Data) -> [TexterColorValue] {
    guard let values = try? JSONDecoder().decode([TexterColorValue].self, from: data),
          (1...5).contains(values.count), values.allSatisfy(\.isValid),
          Set(values.map(\.id)).count == values.count else { return [] }
    return values
  }

  static func colors(index: Int, customData: Data) -> [Color] {
    if index == customIndex - 2 { return [.black] }
    if index == customIndex - 1 { return [.white] }
    if index == customIndex {
      let custom = customValues(from: customData)
      if !custom.isEmpty { return custom.map(\.color) }
    }
    return ColorUtil.shared.getColor(index: index)
  }

  static func editCustomColors() { TexterCustomColorWindow.shared.show() }
}

struct TexterColorValue: Codable, Identifiable {
  let id: UUID
  let red: Double
  let green: Double
  let blue: Double

  init(id: UUID = UUID(), red: Double, green: Double, blue: Double) {
    self.id = id
    self.red = red
    self.green = green
    self.blue = blue
  }

  var isValid: Bool { [red, green, blue].allSatisfy { $0.isFinite && (0...1).contains($0) } }
  var color: Color { Color(.sRGB, red: red, green: green, blue: blue) }

  @MainActor
  init(_ color: Color, id: UUID) {
    let rgb = NSColor(color).usingColorSpace(.sRGB) ?? .systemBlue
    self.init(id: id, red: Double(rgb.redComponent), green: Double(rgb.greenComponent), blue: Double(rgb.blueComponent))
  }
}

@MainActor
private final class TexterCustomColorWindow: NSObject, NSWindowDelegate {
  static let shared = TexterCustomColorWindow()
  private var window: NSWindow?

  func show() {
    if let window {
      NSApp.activate(ignoringOtherApps: true)
      window.makeKeyAndOrderFront(nil)
      return
    }
    let state = AppState.shared
    let values = TexterPalette.customValues(from: state.customColorsData)
    let content = TexterCustomColorEditor(values: values, onSave: { [weak self] values in
      guard let self else { return }
      guard let data = try? JSONEncoder().encode(values) else { return }
      state.customColorsData = data
      state.colorIndex = TexterPalette.customIndex
      self.window?.close()
    }, onCancel: { [weak self] in self?.window?.close() })
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 420),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
    window.title = values.isEmpty ? String(localized: "Add Custom Gradient") : String(localized: "Edit Custom Gradient")
    window.isReleasedWhenClosed = false
    window.contentView = NSHostingView(rootView: content)
    window.delegate = self
    window.center()
    self.window = window
    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
  }

  func windowWillClose(_ notification: Notification) {
    NSColorPanel.shared.orderOut(nil)
    window = nil
  }
}

struct TexterCustomColorEditor: View {
  @State private var values: [TexterColorValue]
  let onSave: ([TexterColorValue]) -> Void
  let onCancel: () -> Void

  init(values: [TexterColorValue],
       onSave: @escaping ([TexterColorValue]) -> Void, onCancel: @escaping () -> Void) {
    _values = State(initialValue: values.isEmpty ? [TexterColorValue(red: 0.25, green: 0.65, blue: 1)] : values)
    self.onSave = onSave
    self.onCancel = onCancel
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Choose 1–5 gradient colors")
        .font(.system(size: 13, weight: .semibold))
      RoundedRectangle(cornerRadius: 6)
        .fill(LinearGradient(colors: values.map(\.color), startPoint: .leading, endPoint: .trailing))
        .frame(height: 20)
      VStack(alignment: .leading, spacing: 8) {
        Text("Live Preview")
          .font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
        TexterView(previewColors: values.map(\.color), fitsAvailableWidth: true)
          .frame(maxWidth: .infinity, minHeight: 34)
          .padding(.horizontal, 12)
          .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
      }
      VStack(spacing: 8) {
        ForEach(Array(values.enumerated()), id: \.element.id) { index, value in
          HStack {
            ColorPicker("Color \(index + 1)", selection: Binding(
              get: { values.first { $0.id == value.id }?.color ?? value.color },
              set: { color in
                guard let currentIndex = values.firstIndex(where: { $0.id == value.id }) else { return }
                values[currentIndex] = TexterColorValue(color, id: value.id)
              }
            ), supportsOpacity: false)
            Spacer()
            Button {
              guard values.count > 1 else { return }
              values.removeAll { $0.id == value.id }
            } label: { Image(systemName: "minus.circle") }
              .buttonStyle(.plain)
              .disabled(values.count <= 1)
              .help(String(localized: "Remove Color"))
          }
        }
      }
      Spacer(minLength: 0)
      HStack {
        Button("Add Color") {
          guard values.count < 5, let last = values.last else { return }
          values.append(TexterColorValue(red: last.red, green: last.green, blue: last.blue))
        }
        .disabled(values.count >= 5)
        Spacer()
        Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
        Button("Save") { onSave(values) }
          .buttonStyle(.borderedProminent)
          .keyboardShortcut(.defaultAction)
      }
    }
    .padding(18)
    .frame(width: 360, height: 420)
  }
}

struct TexterPaletteView: View {
  @ObservedObject private var state = AppState.shared
  var columns = 10
  var beforeEditing: () -> Void = {}

  var body: some View {
    let hasCustom = !TexterPalette.customValues(from: state.customColorsData).isEmpty
    VStack(alignment: .leading, spacing: 6) {
      Text("Colorful")
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.secondary)

      LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 20), spacing: 4), count: columns), spacing: 2) {
        ForEach(0...TexterPalette.customIndex, id: \.self) { index in
          let selected = state.colorIndex == index
          let custom = index == TexterPalette.customIndex
          let pureWhite = index == TexterPalette.customIndex - 1
          Button {
            if custom { editCustom() } else { state.colorIndex = index }
          } label: {
            Circle()
              .fill(LinearGradient(colors: custom && !hasCustom ? [.secondary.opacity(0.15)] : TexterPalette.colors(index: index, customData: state.customColorsData),
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
              .overlay(Circle().strokeBorder(pureWhite ? Color.gray.opacity(0.7) : Color.white.opacity(0.2),
                                             lineWidth: pureWhite ? 1 : 0.5))
              .overlay {
                if custom {
                  Image(systemName: hasCustom ? "pencil" : "plus")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(hasCustom ? Color.white : .primary)
                    .shadow(color: .black.opacity(hasCustom ? 0.5 : 0), radius: 1, y: 1)
                } else if selected {
                  Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 1, y: 1)
                }
              }
              .frame(width: 20, height: 20)
              .frame(width: 25, height: 25)
              .overlay(Circle().strokeBorder(.primary.opacity(selected ? 0.6 : 0), lineWidth: 1))
              .contentShape(Circle())
          }
          .buttonStyle(.plain)
          .help(custom ? (hasCustom ? String(localized: "Edit Custom Gradient") : String(localized: "Add Custom Gradient")) : String(localized: "Colorful"))
          .accessibilityLabel(custom ? Text("Custom Colors") : Text("Colorful") + Text(verbatim: " \(index + 1)"))
          .accessibilityAddTraits(selected ? .isSelected : [])
          .accessibilityIdentifier("texter.color.\(index)")
        }
      }
    }
  }

  private func editCustom() {
    beforeEditing()
    TexterPalette.editCustomColors()
  }
}
