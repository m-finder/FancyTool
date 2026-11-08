import AppKit

@MainActor
enum TexterFont {
  struct Family: Identifiable {
    let id: String
    let displayName: String
  }

  static func installedFamilies() -> [Family] {
    let manager = NSFontManager.shared
    return manager.availableFontFamilies
      .filter { !$0.hasPrefix(".") }
      .map { Family(id: $0, displayName: manager.localizedName(forFamily: $0, face: nil)) }
      .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
  }

  static func resolve(family: String, size: CGFloat,
                      systemWeight: NSFont.Weight = .regular) -> NSFont {
    if !family.isEmpty,
       let font = NSFontManager.shared.font(withFamily: family, traits: [], weight: 5, size: size) {
      return font
    }
    return .systemFont(ofSize: size, weight: systemWeight)
  }
}
