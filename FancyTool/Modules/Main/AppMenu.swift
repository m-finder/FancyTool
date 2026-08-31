//
//  AppMenu.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import SwiftUI

@MainActor
class AppMenu {

  public static var shared = AppMenu()

  private var menu: NSMenu
  private var actions =  AppMenuActions.shared


  init(){

    self.menu = NSMenu()

    // MARK: - 菜单遍历
    AppMenuItem.shared.menus().forEach { item in

      // MARK: - 分割线
      if item.isSeparator {
        self.menu.addItem(NSMenuItem.separator())
        return
      }

      // MARK: - 功能菜单
      if item.state {
        self.addMenuItem(
          title: item.title!,
          action: item.action!,
          state: item.state
        )
        return
      }

      // MARK: - 快捷键菜单
      if item.key != nil {
        self.addMenuItem(
          title: item.title!,
          action: item.action!,
          key: item.key!
        )
        return
      }

      // MARK: - 普通菜单
      if item.key == nil {
        self.addMenuItem(
          title: item.title!,
          action: item.action!
        )
        return
      }

    }
  }

  // MARK: - 添加菜单
  private func addMenuItem(title: String, action: Selector, key: String){
    let item = NSMenuItem(
      title: title,
      action: action,
      keyEquivalent: key
    )
    item.target = actions
    self.menu.addItem(item)
  }

  // MARK: - 添加菜单
  private func addMenuItem(title: String, action: Selector){
    let item = NSMenuItem(
      title: title,
      action: action,
      keyEquivalent: ""
    )
    item.target = actions
    self.menu.addItem(item)
  }

  // MARK: - 添加菜单
  private func addMenuItem(title: String, action: Selector, state: Bool){
    let item = NSMenuItem(
      title: title,
      action: action,
      keyEquivalent: ""
    )
    item.target = actions
    item.state = state ? .on : .off
    self.menu.addItem(item)
  }

  // MARK: - 获取所有菜单
  func getMenus() -> NSMenu {
    return self.menu
  }

  // MARK: - 刷新功能菜单的勾选状态
  public func refreshFeatureStates() {
    let stateMappings: [Selector: () -> Bool] = [
      #selector(AppMenuActions.hidder(_:)): { AppState.shared.showHidder },
      #selector(AppMenuActions.texter(_:)): { AppState.shared.showTexter },
      #selector(AppMenuActions.paster(_:)): { AppState.shared.showPaster },
      #selector(AppMenuActions.rounder(_:)): { AppState.shared.showRounder },
      #selector(AppMenuActions.monitor(_:)): { AppState.shared.showMonitor },
      #selector(AppMenuActions.shotter(_:)): { AppState.shared.showShotter }
    ]
    
    for menuItem in menu.items {
      guard let action = menuItem.action,
            let stateProvider = stateMappings[action] else { continue }
      menuItem.state = stateProvider() ? .on : .off
    }
  }

}
