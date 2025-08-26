//
//  AppDelegate.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/8/25.
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
  
  private var runner: NSStatusItem
  
  override init(){
    self.runner = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  }
  
  // 启动完成
  func applicationDidFinishLaunching(_ notification: Notification) {
    
    // Runner
    Runner.shared.mound(item: self.runner)
    
    // Texter
    if(AppState.shared.showTexter){
      Texter.shared.mount()
    }
    
    // Hidder
    if(AppState.shared.showHidder){
      Hidder.shared.mount()
      DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
        Hidder.shared.toggle()
      })
    }
    
    // Paster
    if(AppState.shared.showPaster){
      Paster.shared.mount()
    }
    
    // Rounder
    if(AppState.shared.showRounder){
      Rounder.shared.mount()
    }
    
    // 监听应用进入后台
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appDidResignActive),
      name: NSApplication.didResignActiveNotification,
      object: nil
    )
    
    // 监听应用回到前台
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appDidBecomeActive),
      name: NSApplication.didBecomeActiveNotification,
      object: nil
    )
  }
  
  @objc private func appDidResignActive() {
    // 后台时关闭动画
    print("app 进入后台模式")
//    AppState.shared.showShimmer = false
  }
  
  @objc private func appDidBecomeActive() {
    // 前台时恢复动画（如果之前是开启的）
    print("app 进入前台模式")
//    AppState.shared.showShimmer = true
  }
  
}
