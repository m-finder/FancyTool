import AppKit

@MainActor
final class AppMenu {
  static let shared = AppMenu()

  private let menu = NSMenu()
  private let actions = AppMenuActions.shared

  private init() {
    for entry in AppMenuItem.shared.menus() {
      if entry.isSeparator {
        menu.addItem(.separator())
        continue
      }
      guard let title = entry.title, let action = entry.action else { continue }
      let item = NSMenuItem(title: title, action: action, keyEquivalent: entry.key ?? "")
      item.target = actions
      item.state = entry.state ? .on : .off
      menu.addItem(item)
    }
  }

  func getMenus() -> NSMenu { menu }

  func refreshFeatureStates() {
    let state = AppState.shared
    let featureStates: [Selector: Bool] = [
      #selector(AppMenuActions.hidder(_:)): state.showHidder,
      #selector(AppMenuActions.texter(_:)): state.showTexter,
      #selector(AppMenuActions.paster(_:)): state.showPaster,
      #selector(AppMenuActions.rounder(_:)): state.showRounder,
      #selector(AppMenuActions.monitor(_:)): state.showMonitor,
      #selector(AppMenuActions.duo(_:)): state.showDuo,
      #selector(AppMenuActions.shotter(_:)): state.showShotter
    ]
    for item in menu.items {
      guard let action = item.action, let enabled = featureStates[action] else { continue }
      item.state = enabled ? .on : .off
    }
  }
}
