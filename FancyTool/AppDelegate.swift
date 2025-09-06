//
//  AppDelegate.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/8/25.
//

import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
  
  private var runner: NSStatusItem
  private var timer: DispatchSourceTimer?
  
  override init(){
    self.runner = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  }
  
  // 启动完成
  func applicationDidFinishLaunching(_ notification: Notification) {
    
    // 初始化图标和菜单
    Runner.shared.mount(to: self.runner)
  
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
    let queue = DispatchQueue(label: "cpu.timer", qos: .utility)
    timer = DispatchSource.makeTimerSource(queue: queue)
    timer?.schedule(deadline: .now(), repeating: 5)
    timer?.setEventHandler {
      // todo 更多监控
      CpuUtil.shared.refresh()
      // 按CPU使用率更新图片
      DispatchQueue.main.async {
        Runner.shared.refresh(usage: CpuUtil.shared.usage)
      }
    }
    timer?.resume()
    
  }
}
