//
//  AppDelegate.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/8/25.
//

import SwiftUI

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

    AppState.shared.applyAppearance()

    // 初始化图标和菜单
    Runner.shared.mount()
    
    // Hidder：macOS 27 及以上不提供该功能。
    if Hidder.isSupported {
      if AppState.shared.showHidder {
        Hidder.shared.mount(toggleAfterMount: true)
      }
    } else {
      AppState.shared.showHidder = false
    }
    
    // Texter
    if AppState.shared.showTexter {
      Texter.shared.mount()
    }
    
    
    // Paster
    if AppState.shared.showPaster {
      Paster.shared.mount()
    }
    
    
    // Rounder
    if AppState.shared.showRounder {
      Rounder.shared.mount()
    }
    
    
    // Monitor
    if AppState.shared.showMonitor {
      Monitor.shared.mount()
    }

    // Duo
    if AppState.shared.showDuo {
      Duo.shared.mount()
    }

    // Shotter
    if AppState.shared.showShotter {
      Shotter.shared.mount()
    }
    
    // 开始监控
    SystemMetrics.shared.start()
    UpdateChecker.shared.start()
  }
  
  // 失去焦点
  func applicationDidResignActive(_ notification: Notification) {
    
    // 关闭 Paster 的 window
    Paster.shared.hide()

  }

  func applicationWillTerminate(_ notification: Notification) {
    DuoMetrics.shared.stop()
    SystemMetrics.shared.stop()
  }
}
