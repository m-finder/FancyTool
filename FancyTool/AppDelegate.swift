//
//  AppDelegate.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate{
  private var mainItem: NSStatusItem?
  
  func applicationDidFinishLaunching(_ aNotification: Notification) {
    // 初始化一个菜单栏对象
    initMainIcon()
    // 创建一个宿主视图
    initHostingView()
    // 初始化菜单
    initMainMenu()
  }
  
  private func initMainIcon(){
    // 主状态栏初始化
    mainItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    mainItem?.button?.title = " "
  }
  
  private func initHostingView(){
    let hostingView = NSHostingView(rootView: ContentView().fixedSize())
    // 将视图挂载到状态栏按钮
    mainItem?.button?.addSubview(hostingView)
    // 配置自动布局
    hostingView.translatesAutoresizingMaskIntoConstraints = false
    // 将宿主视图四边锚定到按钮边界，也就是将视图展开
    hostingView.topAnchor.constraint(equalTo: (mainItem?.button!.topAnchor)!).isActive = true
    hostingView.bottomAnchor.constraint(equalTo: (mainItem?.button!.bottomAnchor)!).isActive = true
    hostingView.leadingAnchor.constraint(equalTo: (mainItem?.button!.leadingAnchor)!).isActive = true
    hostingView.trailingAnchor.constraint(equalTo: (mainItem?.button!.trailingAnchor)!).isActive = true
  }
  
  private func initMainMenu(){
     
    let menu = NSMenu()
    menu.addItem(NSMenuItem.separator())
    menu.addItem(NSMenuItem(title: String(localized: "Setting"), action: #selector(settingView), keyEquivalent: "s"))
    menu.addItem(NSMenuItem(title: String(localized: "Quit App"), action: #selector(quit), keyEquivalent: "q"))
    mainItem?.menu = menu
  }
  
  @IBAction func settingView(_ sender: Any) {
      NSApp.activate(ignoringOtherApps: true)
  }
  
  @IBAction func quit(_ sender: Any){
      NSApplication.shared.terminate(nil)
  }
}
