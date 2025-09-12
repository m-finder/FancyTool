//
//  AppMenu.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import Foundation
import SwiftUI

@MainActor
class AppMenu {
  
  public static var shared = AppMenu()
  
  private var menu: NSMenu
  private var actions =  AppMenuActions.shared
  
  
  init(){
    
    self.menu = NSMenu()

    AppMenuItem.shared.menus().forEach { item in
      
      if item.isSeparator {
        self.menu.addItem(NSMenuItem.separator())
        return
      }
      
      if item.state {
        self.addMenuItem(
          title: item.title!,
          action: item.action!,
          state: item.state
        )
        return
      }
      
      if item.key != nil {
        self.addMenuItem(
          title: item.title!,
          action: item.action!,
          key: item.key!
        )
        return
      }
      
      if item.key == nil {
        self.addMenuItem(
          title: item.title!,
          action: item.action!
        )
        return
      }
      
    }
  }
  
  private func addMenuItem(title: String, action: Selector, key: String){
    let item = NSMenuItem(
      title: title,
      action: action,
      keyEquivalent: key
    )
    item.target = actions
    self.menu.addItem(item)
  }
  
  private func addMenuItem(title: String, action: Selector){
    let item = NSMenuItem(
      title: title,
      action: action,
      keyEquivalent: ""
    )
    item.target = actions
    self.menu.addItem(item)
  }
  
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
  
  func getMenus() -> NSMenu {
    return self.menu
  }
  
}
