//
//  Runner.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import SwiftUI
import SwiftData

class Runner {
  
  private var item: NSStatusItem?
  private var settingsWindow: NSWindow?
  @AppStorage("runnerId") private var runnerId: String = "10001b46-eb35-4625-bb4a-bc0a25c3310b"
  
  deinit {
    item = nil
  }
  
  // 挂载
  @MainActor public func mount(){
    initMainIcon()
    initHostingView()
    initMainMenu()
  }
  
  // 主状态栏初始化
  private func initMainIcon(){
    item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    item?.button?.imagePosition = .imageLeading
    item?.button?.title = ""
  }
  
  // 初始化 runner 视图
  @MainActor
  private func initHostingView(){
    let sharedModelContainer = RunnerHandler.shared.container
    let size: CGFloat = 20
    let hostingView = NSHostingView(rootView: RunnerView(
      height: size,
      runnerId: $runnerId
    ).fixedSize()
      .frame(minWidth: 40, maxWidth: .infinity)
      .modelContainer(sharedModelContainer))
    
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
  
  // 初始化菜单
  private func initMainMenu(){
    
    let menu = NSMenu()
    menu.addItem(NSMenuItem.separator())
    let settingItem = NSMenuItem(title: String(localized: "Setting"), action: #selector(settingView), keyEquivalent: "s")
    settingItem.target = self
    menu.addItem(settingItem)
    
    let quitItem = NSMenuItem(title: String(localized: "Quit App"), action: #selector(quit), keyEquivalent: "q")
    quitItem.target = self
    menu.addItem(quitItem)
    
    item?.menu = menu
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
  
}
