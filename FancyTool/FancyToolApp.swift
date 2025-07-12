//
//  FancyToolApp.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//
import SwiftUI
import SwiftData

@main
struct FancyToolApp: App {
  
  @StateObject private var item: HostingViewItem
  
  init(){
    _ = RunnerHandler()
    let actions = AppMenuActions()
    let menuItems: [MenuItem] = MenuItem.menus()
    let appMenu = AppMenu(actions: actions, items: menuItems)
    
    _item = StateObject(
      wrappedValue: HostingViewItem(
        view: RunnerMainView(height: 22).frame(
          minWidth: 40,
          maxWidth: .infinity
        ).fixedSize(),
        menu: appMenu.getMenus()
      )
    )
    
    print("Fancy Tool App init")
  }
  
  var body: some Scene {
    Settings{
      EmptyView()
    }
  }
}
