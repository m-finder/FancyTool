//
//  AppDelegate.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/8/25.
//

//import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
  
  private var runner: NSStatusItem

  override init(){
    self.runner = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  }
  
  // 启动完成
  func applicationDidFinishLaunching(_ notification: Notification) {
    
    // 初始化按钮和图标
    if let button = runner.button {
      if let image = NSImage(named: "m-finder") {
        image.size = NSSize(width: 28, height: 28)
        button.image = image
        button.target = self
      }
    }
    // 初始化菜单
    runner.menu = AppMenu.shared.getMenus()

    // Hidder
    if(AppState.shared.showHidder){
      Hidder.shared.mount()
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
        Hidder.shared.toggle()
      })
    }

    //    // Runner
    //    Runner.shared.mound(item: self.runner)
    //
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
    
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appDidWake),
      name: NSWorkspace.sessionDidBecomeActiveNotification,
      object: NSWorkspace.shared
    )
    
    // 监听应用激活状态变化（从后台到前台）
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(screenDidWake),
      name: NSApplication.didChangeScreenParametersNotification,
      object: nil
    )
    
    // 监听屏幕唤醒（可能间接导致应用唤醒）
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(screenDidWake),
      name: NSWorkspace.screensDidWakeNotification,
      object: nil
    )
    
    // 监听系统进入休眠
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(systemWillSleep),
      name: NSWorkspace.willSleepNotification,
      object: NSWorkspace.shared
    )
    
    // 监听系统从休眠唤醒
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(systemDidWake),
      name: NSWorkspace.didWakeNotification,
      object: NSWorkspace.shared
    )
  }
  
  @IBAction private func appDidResignActive(_: Any) {
    // 后台时关闭动画
    print("app 进入后台模式")
    print("当前线程: \(Thread.current)")
    print("主线程是否空闲: \(Thread.main.isExecuting)")
  }
  
  @IBAction private func appDidBecomeActive(_: Any) {
    // 前台时恢复动画（如果之前是开启的）
    print("app 进入前台模式")
  }
  
  // 应用从休眠中唤醒
  @IBAction private func appDidWake(_ notification: Notification) {
    print("应用被唤醒 - 时间: \(Date())")
    print("唤醒通知信息: \(notification.userInfo ?? [:])")
    // 打印调用栈，辅助定位唤醒源头
    print("唤醒时调用栈: \(Thread.callStackSymbols)")
  }
  
  // 屏幕唤醒
  @IBAction private func screenDidWake(_ notification: Notification) {
    print("屏幕唤醒 - 可能触发应用唤醒")
  }
  
  // 电池唤醒
  @IBAction private func systemWillSleep(_ notification: Notification) {
    print("系统即将进入休眠 - 时间: \(Date())")
  }
  
  @IBAction private func systemDidWake(_ notification: Notification) {
    print("系统从休眠唤醒 - 时间: \(Date())")
    print("唤醒时调用栈: \(Thread.callStackSymbols)")
  }

}
