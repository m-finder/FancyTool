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
  @AppStorage("currentRunnerId") private var currentRunnerId: String = "A3AF9595-F3FC-4A4F-A134-8F9CED4B761D"
    
  
  deinit {
    item = nil
  }
  
  @MainActor public func mount(){
    initMainIcon()
    initHostingView()
    initMainMenu()
  }
  
  private func initMainIcon(){
    // 主状态栏初始化
    item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    item?.button?.imagePosition = .imageLeading
    item?.button?.title = ""
  }
  
  @MainActor
  private func initHostingView(){
    let sharedModelContainer = RunnerHandler.shared.container
    let size: CGFloat = 24
    let hostingView = NSHostingView(rootView: RunnerView(
      height: size,
      currentRunnerId: $currentRunnerId
    ).modelContainer(sharedModelContainer).fixedSize())
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
    let settingItem = NSMenuItem(title: String(localized: "Setting"), action: #selector(settingView), keyEquivalent: "s")
    settingItem.target = self
    menu.addItem(settingItem)
    
    let quitItem = NSMenuItem(title: String(localized: "Quit App"), action: #selector(quit), keyEquivalent: "q")
    quitItem.target = self
    menu.addItem(quitItem)
    
    item?.menu = menu
  }
  
  @IBAction func settingView(_ sender: Any) {
    let sharedModelContainer = RunnerHandler.shared.container
    if settingsWindow == nil {
        
      let settingsView = SettingsView()
            .frame(width: 455, height: 580)
            .modelContainer(sharedModelContainer)
        
        settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 0, height: 0),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        settingsWindow?.center()
        settingsWindow?.title = String(localized: "Setting")
        settingsWindow?.isReleasedWhenClosed = false
        settingsWindow?.contentView = NSHostingView(rootView: settingsView)
    }
    settingsWindow?.makeKeyAndOrderFront(nil)
    settingsWindow?.orderFrontRegardless()
    NSApp.activate(ignoringOtherApps: true)
  }
  
  @IBAction func quit(_ sender: Any){
    NSApplication.shared.terminate(nil)
  }
  
}
