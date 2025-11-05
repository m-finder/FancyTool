//
//  AppDelegate.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/8/25.
//

import SwiftUI
import SystemInfoKit

class AppDelegate: NSObject, NSApplicationDelegate {
  
  
  private var timer: DispatchSourceTimer?
  
  // 启动完成
  func applicationDidFinishLaunching(_ notification: Notification) {
    
    if let preferredLanguages = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String],
           let currentLanguage = preferredLanguages.first {
            print("当前系统首选语言: \(currentLanguage)") // 例如："zh-Hans-CN"
        } else {
            print("未能获取到系统语言")
        }
    
    // 初始化图标和菜单
    Runner.shared.mount()
    
    // Hidder
    if(AppState.shared.showHidder){
      Hidder.shared.mount()
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
        Hidder.shared.toggle()
      })
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
      DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: {
        Monitor.shared.mount()
      })
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
  }
}
