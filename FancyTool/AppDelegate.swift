//
//  AppDelegate.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/8/25.
//

import SwiftUI
import SystemInfoKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
  
  
  // 启动完成
  func applicationDidFinishLaunching(_ notification: Notification) {
    // Prevent two copies of the same bundle from concurrently mutating the
    // app-scoped JSON manifests and media files.
    guard AppInstanceLock.shared.acquire() else {
      let alert = NSAlert()
      alert.messageText = "FancyTool is already running"
      alert.informativeText = "Another copy is using this app's local data."
      alert.addButton(withTitle: "OK")
      alert.runModal()
      NSApp.terminate(nil)
      return
    }

    // 初始化图标和菜单
    Runner.shared.mount()
    
    // Hidder
    if(AppState.shared.showHidder){
      Hidder.shared.mount(toggleAfterMount: true)
    }
    
    // Texter
    if(AppState.shared.showTexter){
      Texter.shared.mount()
    }
    
    
    // Paster
    if(AppState.shared.showPaster){
      Paster.shared.mount()
    }
    
    
    // Rounder
    if(AppState.shared.showRounder){
      Rounder.shared.mount()
    }
    
    
    // Monitor
    if(AppState.shared.showMonitor){
      Monitor.shared.mount()
    }

    // Shotter
    if(AppState.shared.showShotter){
      Shotter.shared.mount()
    }
    
    // 开始监控
    AppState.shared.start()
  }
  
  // 失去焦点
  func applicationDidResignActive(_ notification: Notification) {
    
    // 关闭 Monitor 的 popover
    if Monitor.shared.popover.isShown {
      Monitor.shared.popover.close()
    }
    
    // 关闭 Texter 的 popover
    if Texter.shared.popover.isShown {
      Texter.shared.popover.close()
    }
    
    // 关闭 Paster 的 window
    if Paster.shared.window != nil {
      Paster.shared.window?.close()
    }

  }
}
