//
//  Main.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/7.
//

import SwiftUI
import SwiftData
import AppKit

class Menu {
  
  
  var hidder: Hidder!
  var state = AppState.shared
  private var settingsWindow: NSWindow?
  private var aboutWindow: NSWindow?
  
  init() {
          print("Menu initialized")
  }
  
  
  func getMenu() -> NSMenu {
    
    let menu = NSMenu()
    
    // hidder 菜单
    let hidderMenu = NSMenuItem(
      title: "Hidder",
      action: #selector(toggleHidder(_:)),
      keyEquivalent: ""
    )
    hidderMenu.target = self
    hidderMenu.state = state.showHidder ? .on : .off
    menu.addItem(hidderMenu)
    
    // 间隔线
    menu.addItem(NSMenuItem.separator())
        
    // 设置菜单
    let settingItem = NSMenuItem(
      title: String(localized: "Setting"),
      action: #selector(settingView),
      keyEquivalent: "s"
    )
    settingItem.target = self
    settingItem.isEnabled = true
    menu.addItem(settingItem)
    
    // 关于菜单
    let aboutItem = NSMenuItem(
      title: String(localized: "About"),
      action: #selector(aboutView),
      keyEquivalent: "a"
    )
    aboutItem.target = self
    aboutItem.isEnabled = true
    menu.addItem(aboutItem)
    
    // 退出程序
    let quitItem = NSMenuItem(
      title: String(localized: "Quit App"),
      action: #selector(quit),
      keyEquivalent: "q"
    )
    quitItem.target = self
    quitItem.isEnabled = true
    menu.addItem(quitItem)
    return menu
  }
  
  /// 创建并显示通用设置窗口
  private func showWindow<T: View>(
    window: inout NSWindow?,
    title: String,
    contentView: T
  ) {
    // 惰性创建窗口
    if window == nil {
      // 创建基础滚动视图
      let rootView = ScrollView {
        contentView.frame(maxWidth: .infinity)
      }.frame(width: 440, height: 500)

      
      // 配置窗口属性
      window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 425, height: 800),
        styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
        backing: .buffered,
        defer: false
      )
      window?.center()
      window?.title = title
      window?.isReleasedWhenClosed = false
      window?.contentView = NSHostingView(rootView: rootView)
      
      // 固定窗口尺寸
      window?.styleMask.remove(.resizable)
      window?.minSize = NSSize(width: 425, height: 800)
      window?.maxSize = NSSize(width: 425, height: 800)
    }
    
    // 激活并显示窗口
    window?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }
  
  // 关于页面
  @IBAction func aboutView(_ sender: Any) {
    showWindow(
      window: &aboutWindow,
      title: String(localized: "About"),
      contentView: AboutView()
    )
  }
  
  // 设置页面
  @IBAction func settingView(_ sender: Any) {
    showWindow(
      window: &settingsWindow,
      title: String(localized: "Setting"),
      contentView: SettingsView()
    )
  }
  
  
  
  @IBAction func quit(_ sender: Any){
    NSApplication.shared.terminate(nil)
  }
  
  // 关闭窗口时释放资源
  func windowWillClose(_ notification: Notification) {
    
    if let window = notification.object as? NSWindow, window == settingsWindow {
      // 释放宿主视图
      settingsWindow?.contentView = nil
      // 释放窗口引用
      settingsWindow = nil
      // 清理缓存
      RunnerModel.cleanupCache()
    }
  }
  
  // 显示或隐藏 Hidder
  @IBAction func toggleHidder(_ sender: NSStatusBarButton){
    state.showHidder.toggle()
    sender.state = state.showHidder ? .on : .off
    hidder.update()
  }
  
  // Hidder 点击事件
  @IBAction func hidderClick(_ sender: NSStatusBarButton?) {
    // 从两个图标中获取靠左的一个，然后执行 toggle
    hidder.hidderCollapseMenuBar()
  }
  
}
