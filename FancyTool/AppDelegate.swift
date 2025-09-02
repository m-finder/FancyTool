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
  private var lastUsage: Double = 0.0

  override init(){
    self.runner = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  }
  
  // 启动完成
  func applicationDidFinishLaunching(_ notification: Notification) {
    
    // 初始化按钮和图标
    Runner.shared.mound(item: self.runner)
    
    // 添加CPU使用率显示
    let queue = DispatchQueue(label: "cpu.timer", qos: .utility)
    timer = DispatchSource.makeTimerSource(queue: queue)
    timer?.schedule(deadline: .now(), repeating: 5)
    timer?.setEventHandler { [weak self] in
      CpuUtil.shared.refresh()
      DispatchQueue.main.async {
        let newUsage = CpuUtil.shared.usage
        if abs(newUsage - (self?.lastUsage ?? Double(0.0))) >= 0.1 {
          self?.lastUsage = newUsage
          self?.runner.button?.title = String(format: "%4.1f%%", newUsage)
        }
      }
    }
    timer?.resume()

    // Hidder
    if(AppState.shared.showHidder){
      Hidder.shared.mount()
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
        Hidder.shared.toggle()
      })
    }

    //    // Texter
    //    if(AppState.shared.showTexter){
    //      Texter.shared.mount()
    //    }
    

    //
    //    // Paster
    //    if(AppState.shared.showPaster){
    //      Paster.shared.mount()
    //    }
    //
    
    // Rounder
    if(AppState.shared.showRounder){
      Rounder.shared.mount()
    }

  }
}
