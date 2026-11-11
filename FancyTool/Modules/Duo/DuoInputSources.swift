import AppKit
import Carbon

@MainActor
final class DuoInputSources: NSObject, ObservableObject {
  static let shared = DuoInputSources()
  struct Source: Identifiable {
    let id: String
    let name: String
    let badge: String
    let token: TISInputSource
  }
  @Published private(set) var sources: [Source] = []
  @Published private(set) var currentID = ""
  var currentName: String { sources.first { $0.id == currentID }?.name ?? "—" }
  var shortName: String { sources.first { $0.id == currentID }?.badge ?? "—" }
  @Published private(set) var error: String?
  private var isObserving = false

  func start() {
    guard !isObserving else { return }
    isObserving = true
    let center = DistributedNotificationCenter.default()
    // Menu-bar apps usually stay inactive. The default coalescing behavior
    // suspends input-source updates until AppKit activates the app again.
    for name in [kTISNotifySelectedKeyboardInputSourceChanged!, kTISNotifyEnabledKeyboardInputSourcesChanged!] {
      center.addObserver(self, selector: #selector(inputSourcesChanged(_:)),
                         name: Notification.Name(name as String), object: nil,
                         suspensionBehavior: .deliverImmediately)
    }
    refresh()
  }
  func stop() {
    guard isObserving else { return }
    DistributedNotificationCenter.default().removeObserver(self)
    isObserving = false
  }
  @objc private func inputSourcesChanged(_ notification: Notification) { refresh() }
  private func string(_ source: TISInputSource, _ key: CFString) -> String {
    guard let pointer = TISGetInputSourceProperty(source, key) else { return "" }
    return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
  }
  private func badge(_ source: TISInputSource) -> String {
    let id = string(source, kTISPropertyInputSourceID).lowercased()
    if id.contains("shuangpin") { return "双" }
    if id.contains("pinyin") { return "拼" }
    if id.contains("wubi") { return "五" }
    if id.contains("keylayout.abc") { return "A" }
    guard let property = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages),
          let languages = Unmanaged<CFArray>.fromOpaque(property).takeUnretainedValue() as? [String],
          let language = languages.first else { return String(string(source, kTISPropertyLocalizedName).prefix(2)) }
    if language.hasPrefix("zh") { return language.contains("Hant") ? "繁" : "中" }
    if language.hasPrefix("ja") { return "あ" }
    if language.hasPrefix("ko") { return "한" }
    return String(language.prefix(2)).uppercased()
  }
  func refresh() {
    let filter = [kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource!,
                  kTISPropertyInputSourceIsSelectCapable: kCFBooleanTrue!] as CFDictionary
    guard let list = TISCreateInputSourceList(filter, false).takeRetainedValue() as? [TISInputSource] else { return }
    let next = list.map { Source(id: string($0, kTISPropertyInputSourceID), name: string($0, kTISPropertyLocalizedName), badge: badge($0), token: $0) }
    if !sources.elementsEqual(next, by: { $0.id == $1.id && $0.name == $1.name && $0.badge == $1.badge }) {
      sources = next
    }
    let selected = string(TISCopyCurrentKeyboardInputSource().takeRetainedValue(), kTISPropertyInputSourceID)
    if currentID != selected { currentID = selected }
  }
  func select(_ source: Source) {
    Duo.shared.closePanel()
    // Restore the previous app's focus before choosing its input source.
    DispatchQueue.main.async { [weak self] in
      if TISSelectInputSource(source.token) == noErr {
        self?.error = nil
        self?.refresh()
      } else { self?.error = String(localized: "Unable to switch input source.") }
    }
  }
}
