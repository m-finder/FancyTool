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
  let isSeparator: Bool

  init(title: String? = nil, action: Selector? = nil, key: String? = nil, isSeparator: Bool = false) {
    self.title = title
    self.action = action
    self.key = key
    self.isSeparator = isSeparator
  }

  static func menus() -> [MenuItem] {
    return [
      MenuItem(
        title: String(localized: "About"),
        action:  #selector(AppMenuActions.about(_:)),
        key: "a"
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
        title: String(localized: "Quit App"),
        action:  #selector(AppMenuActions.quit(_:)),
        key: "q"
      ),
     
    ]
  }
}

