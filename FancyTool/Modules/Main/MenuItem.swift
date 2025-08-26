//
//  MenuItem.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//
import SwiftUI

struct MenuItem {
  
  let title: String?
  let action: Selector?
  let key: String?
  let state: Bool
  let isSeparator: Bool

  init(
    title: String? = nil,
    action: Selector? = nil,
    key: String? = nil,
    state: Bool = false,
    isSeparator: Bool = false
  ) {
    self.title = title
    self.action = action
    self.key = key
    self.state = state
    self.isSeparator = isSeparator
  }

  static func menus() -> [MenuItem] {
    return [
      MenuItem(
        title: String(localized: "Texter"),
        action:  #selector(AppMenuActions.texter(_:)),
        state: AppState.shared.showTexter
      ),
      MenuItem(
        title: String(localized: "Hidder"),
        action:  #selector(AppMenuActions.hidder(_:)),
        state: AppState.shared.showHidder
      ),
      MenuItem(
        title: String(localized: "Paster"),
        action:  #selector(AppMenuActions.paster(_:)),
        state: AppState.shared.showPaster
      ),
      MenuItem(
        title: String(localized: "Rounder"),
        action:  #selector(AppMenuActions.rounder(_:)),
        state: AppState.shared.showRounder
      ),
      MenuItem(
        isSeparator: true
      ),
      MenuItem(
        title: String(localized: "Setting"),
        action:  #selector(AppMenuActions.setting(_:)),
        key: "s"
      ),
      MenuItem(
        title: String(localized: "About"),
        action:  #selector(AppMenuActions.about(_:)),
        key: "a"
      ),
      MenuItem(
        title: String(localized: "Quit App"),
        action:  #selector(AppMenuActions.quit(_:)),
        key: "q"
      ),
    ]
  }
}

