//
//  Runner.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import SwiftUI
import SwiftData

class Runner: NSObject, NSWindowDelegate {
  
  var item: NSStatusItem?
  private var settingsWindow: NSWindow?
  @ObservedObject var state = AppState.shared
  
  deinit {
    item = nil
  }
  
  // 挂载
  @MainActor public func mount(menu: NSMenu){
    // 主状态栏初始化
    initMainIcon()
    // 初始化 runner 视图
    initHostingView()
    // 初始化菜单
    item?.menu = menu
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
    
    let hostingView = NSHostingView(
      rootView: RunnerView(
      height: size,
    ).fixedSize().frame(minWidth: 40, maxWidth: .infinity).modelContainer(sharedModelContainer))
    
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
  
}
