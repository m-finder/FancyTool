//
//  AppDelegate.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate{
  
  
  // 菜单
  private let menu = Menu()
  // Runner
  private let runner = Runner()
  
  private var activity: NSObjectProtocol?
  
  // 程序启动项
  func applicationDidFinishLaunching(_ aNotification: Notification) {
    // 挂载 Runner
    runner.mount(menu: menu.setup())
  }
  
  // 程序终结项
  func applicationWillTerminate(_ notification: Notification) {
      // 清理资源
      if let activity = activity {
          ProcessInfo.processInfo.endActivity(activity)
      }
      RunnerModel.cleanupCache()
  }
}
