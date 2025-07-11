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
  @ObservedObject var state = AppState.shared
  
  init(){
    let container = RunnerHandler.shared.container
    let actions = AppMenuActions()
    let menuItems: [MenuItem] = MenuItem.menus()
    let appMenu = AppMenu(actions: actions, items: menuItems)

    _item = StateObject(
      wrappedValue: HostingViewItem(
        view: RunnerView(height: 22).frame(
          minWidth: 40,
          maxWidth: .infinity
        ).fixedSize().modelContainer(container),
        menu: appMenu.getMenus()
      )
    )
    
  }
  
  var body: some Scene {
    Settings{
      EmptyView()
    }
  }
}
