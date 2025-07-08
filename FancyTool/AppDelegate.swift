//
//  AppDelegate.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate{
  
  @ObservedObject var state = AppState.shared
  // 菜单
  private let menu = Menu()
  // Runner
  private let runner = Runner()
  // Hidder
  private let hidder = Hidder()
  
  // 程序启动项
  func applicationDidFinishLaunching(_ aNotification: Notification) {
    
    menu.state = state
    hidder.state = state
    
    // 挂载 Runner
    print("Runner mount")
    runner.mount(menu: menu.getMenu())

    if(state.showHidder){
      print("Hidder mount")
      self.hidder.mount()
      DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
        self.hidder.hidderCollapseMenuBar()
      })
    }
    
    self.hidder.hidderClickHandler = { [weak self] in
      self?.menu.hidderClick(nil)
    }
    
    menu.hidder = hidder
  }
}
