//
//  AppDelegate.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/8/25.
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
  
  private var item: NSStatusItem
  
  override init(){
    self.item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  }
  
  // 启动完成
  func applicationDidFinishLaunching(_ notification: Notification) {
  
    // Runner
    Runner.shared.mound(item: self.item)

    // Hidder
    if(AppState.shared.showHidder){
      Hidder.shared.mount()
      DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
        Hidder.shared.toggle()
      })
    }
  }
  
}
