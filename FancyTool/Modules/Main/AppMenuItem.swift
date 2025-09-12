//
//  MenuItem.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//
import SwiftUI

@MainActor
struct AppMenuItem {
  
  public static let shared = AppMenuItem()
  
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

  public func menus() -> [AppMenuItem] {
    return [

      AppMenuItem(
        title: String(localized: "Hidder"),
        action:  #selector(AppMenuActions.hidder(_:)),
        state: AppState.shared.showHidder
      ),
      AppMenuItem(
        title: String(localized: "Texter"),
        action:  #selector(AppMenuActions.texter(_:)),
        state: AppState.shared.showTexter
      ),
      AppMenuItem(
        title: String(localized: "Paster"),
        action:  #selector(AppMenuActions.paster(_:)),
        state: AppState.shared.showPaster
      ),
      AppMenuItem(
        title: String(localized: "Rounder"),
        action:  #selector(AppMenuActions.rounder(_:)),
        state: AppState.shared.showRounder
      ),
      AppMenuItem(
        isSeparator: true
      ),
      AppMenuItem(
        title: String(localized: "Setting"),
        action:  #selector(AppMenuActions.setting(_:)),
        key: "s"
      ),
      AppMenuItem(
        title: String(localized: "About"),
        action:  #selector(AppMenuActions.about(_:)),
        key: "a"
      ),
      AppMenuItem(
        title: String(localized: "Quit App"),
        action:  #selector(AppMenuActions.quit(_:)),
        key: "q"
      ),
    ]
  }
}

