//
//  Runner.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import SwiftUI

class Runner {
  
  private var item: NSStatusItem?
  
  public func handle(){
    initMainIcon()
    initHostingView()
    initMainMenu()
    
  }
  
  private func initMainIcon(){
    // 主状态栏初始化
    item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    item?.button?.title = " "
  }
  
  private func initHostingView(){
    let hostingView = NSHostingView(rootView: ContentView().fixedSize())
    // 将视图挂载到状态栏按钮
    item?.button?.addSubview(hostingView)
    // 配置自动布局
    hostingView.translatesAutoresizingMaskIntoConstraints = false
    // 将宿主视图四边锚定到按钮边界，也就是将视图展开
    hostingView.topAnchor.constraint(equalTo: (item?.button!.topAnchor)!).isActive = true
    hostingView.bottomAnchor.constraint(equalTo: (item?.button!.bottomAnchor)!).isActive = true
    hostingView.leadingAnchor.constraint(equalTo: (item?.button!.leadingAnchor)!).isActive = true
    hostingView.trailingAnchor.constraint(equalTo: (item?.button!.trailingAnchor)!).isActive = true
  }
  
  private func initMainMenu(){
    
    let menu = NSMenu()
    menu.addItem(NSMenuItem.separator())
    menu.addItem(NSMenuItem(title: String(localized: "Setting"), action: #selector(settingView), keyEquivalent: "s"))
    menu.addItem(NSMenuItem(title: String(localized: "Quit App"), action: #selector(quit), keyEquivalent: "q"))
    item?.menu = menu
  }
  
  @IBAction func settingView(_ sender: Any) {
    NSApp.activate(ignoringOtherApps: true)
  }
  
  @IBAction func quit(_ sender: Any){
    NSApplication.shared.terminate(nil)
  }
  
}
