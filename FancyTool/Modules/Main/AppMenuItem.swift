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
    var items: [AppMenuItem] = []

    // 菜单折叠仅在 macOS 27 以下提供。
    if Hidder.isSupported {
      items.append(AppMenuItem(
        title: String(localized: "Hidder"),
        action:  #selector(AppMenuActions.hidder(_:)),
        state: AppState.shared.showHidder
      ))
    }

    items += [
      // 炫彩签名
      AppMenuItem(
        title: String(localized: "Texter"),
        action:  #selector(AppMenuActions.texter(_:)),
        state: AppState.shared.showTexter
      ),
      // 剪切板
      AppMenuItem(
        title: String(localized: "Paster"),
        action:  #selector(AppMenuActions.paster(_:)),
        state: AppState.shared.showPaster
      ),
      // 屏幕圆角
      AppMenuItem(
        title: String(localized: "Rounder"),
        action:  #selector(AppMenuActions.rounder(_:)),
        state: AppState.shared.showRounder
      ),
      // 系统监控
      AppMenuItem(
        title: String(localized: "Monitor"),
        action:  #selector(AppMenuActions.monitor(_:)),
        state: AppState.shared.showMonitor
      ),
      // 聚合控制
      AppMenuItem(
        title: String(localized: "Duo"),
        action: #selector(AppMenuActions.duo(_:)),
        state: AppState.shared.showDuo
      ),
      // 截图工具
      AppMenuItem(
        title: String(localized: "Shotter"),
        action: #selector(AppMenuActions.shotter(_:)),
        state: AppState.shared.showShotter
      ),
      // 分割线
      AppMenuItem(
        isSeparator: true
      ),
      // 软件设置
      AppMenuItem(
        title: String(localized: "Setting"),
        action:  #selector(AppMenuActions.setting(_:)),
        key: "s"
      ),
      // 关于
      AppMenuItem(
        title: String(localized: "About"),
        action:  #selector(AppMenuActions.about(_:)),
        key: "a"
      ),
      AppMenuItem(
        title: String(localized: "Check for Updates"),
        action: #selector(AppMenuActions.checkForUpdates(_:))
      ),
      // 退出软件
      AppMenuItem(
        title: String(localized: "Quit App"),
        action:  #selector(AppMenuActions.quit(_:)),
        key: "q"
      ),
    ]

    return items
  }
}
