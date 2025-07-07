//
//  Main.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/7.
//

import SwiftUI
import AppKit

class Menu {

  private let state = AppState.shared
  private var settingsWindow: NSWindow?

  
  func setup() -> NSMenu {
    
    let menu = NSMenu()
    
//    let hidderMenu = NSMenuItem(
//      title: "Hidder",
//      action: #selector(toggleHidder(_:)),
//      keyEquivalent: ""
//    )
//    hidderMenu.target = self
//    hidderMenu.state = state.showHidder ? .on : .off
//    menu.addItem(hidderMenu)
    
    menu.addItem(NSMenuItem.separator())
    let settingItem = NSMenuItem(
      title: String(localized: "Setting"),
      action: #selector(settingView),
      keyEquivalent: "s"
    )
    settingItem.target = self
    menu.addItem(settingItem)
    
    let quitItem = NSMenuItem(
      title: String(localized: "Quit App"),
      action: #selector(quit),
      keyEquivalent: "q"
    )
    quitItem.target = self
    menu.addItem(quitItem)
    return menu
  }
  
  // 设置页面
  @IBAction func settingView(_ sender: Any) {
    let sharedModelContainer = RunnerHandler.shared.container
    if settingsWindow == nil {
      // 创建可滚动视图
      let scrollableSettingsView = ScrollView {
        SettingsView().frame(maxWidth: .infinity)
      }.frame(width: 440, height: 500)
        .modelContainer(sharedModelContainer)
      
      settingsWindow = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 425, height: 800),
        styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
        backing: .buffered,
        defer: false
      )
      settingsWindow?.center()
      settingsWindow?.title = String(localized: "Setting")
      settingsWindow?.isReleasedWhenClosed = false
      settingsWindow?.contentView = NSHostingView(rootView: scrollableSettingsView)
      
      // 固定窗口大小
      settingsWindow?.styleMask.remove(.resizable)
      settingsWindow?.minSize = NSSize(width: 425, height: 800)
      settingsWindow?.maxSize = NSSize(width: 425, height: 800)
    }
    
    settingsWindow?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }
  
  @IBAction func quit(_ sender: Any){
    NSApplication.shared.terminate(nil)
  }
  
  // 关闭窗口时释放资源
  func windowWillClose(_ notification: Notification) {
    settingsWindow = nil
    RunnerModel.cleanupCache()
  }
}
