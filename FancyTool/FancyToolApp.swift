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
  
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  
//  private var item: HostingViewItem
  
//  init(){
//    
//    let menuItems: [MenuItem] = MenuItem.menus()
//    let appMenu = AppMenu(
//      actions: AppMenuActions.shared,
//      items: menuItems
//    )
//    
//    self.item = HostingViewItem(
//      view: RunnerMainView(height: 22).frame(
//        minWidth: 40,
//        maxWidth: .infinity
//      ).fixedSize(),
//      menu: appMenu.getMenus()
//    )
//    
//    if(AppState.shared.showHidder){
//      Hidder.shared.mount()
//      DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
//        Hidder.shared.toggle()
//      })
//    }
//    
//    if(AppState.shared.showTexter){
//      Texter.shared.mount()
//    }
//    
//    if(AppState.shared.showPaster){
//      Paster.shared.mount()
//    }
//    
//    if(AppState.shared.showRounder){
//      Rounder.shared.mount()
//    }
//  }
  
  var body: some Scene {
    Settings{
      EmptyView()
    }
  }
}
