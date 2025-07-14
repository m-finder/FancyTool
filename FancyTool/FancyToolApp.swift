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
    let menuItems: [MenuItem] = MenuItem.menus()
    let appMenu = AppMenu(
      actions: AppMenuActions.shared,
      items: menuItems
    )
    
    _item = StateObject(
      wrappedValue: HostingViewItem(
        view: RunnerMainView(height: 22).frame(
          minWidth: 40,
          maxWidth: .infinity
        ).fixedSize(),
        menu: appMenu.getMenus()
      )
    )
    
    if(AppState.shared.showHidder){
      print("Hidder Auto mount")
      Hidder.shared.mount()
      DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
        Hidder.shared.toggle()
        print("Hidder Auto hidden")
      })
    }
    
    if(AppState.shared.showTexter){
      print("Texter Auto mount")
      Texter.shared.mount()
    }
    
    print("Fancy Tool App inited")
  }
  
  var body: some Scene {
    Settings{
      EmptyView()
    }
  }
}
