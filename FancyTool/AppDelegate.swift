//
//  AppDelegate.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/8/25.
//

import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
  
  
  private var timer: DispatchSourceTimer?
  
  // 启动完成
  func applicationDidFinishLaunching(_ notification: Notification) {
    
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
    
    // 添加CPU使用率显示
    // 直接放在主队列跑，验证是不是线程隔离问题
    timer = DispatchSource.makeTimerSource(queue: .main)
    timer?.schedule(deadline: .now(), repeating: .seconds(5))
    timer?.setEventHandler {
      // 刷新 CPU 使用率
      CpuUtil.shared.refresh()
      NetworkUtil.shared.refresh()
      // 刷新 runner 速度
      Runner.shared.refresh()
    }
    timer?.resume()
    
  }
}
