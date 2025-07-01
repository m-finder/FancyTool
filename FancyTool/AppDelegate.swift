//
//  AppDelegate.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate{
  private var statusItem: NSStatusItem?
  
  func applicationDidFinishLaunching(_ aNotification: Notification) {
    initMainIcon()
  }
  
  private func initMainIcon(){
    // 主状态栏初始化
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusItem?.button?.title = " "
    // 创建一个宿主视图
    let hostingView = NSHostingView(rootView: ContentView().fixedSize().frame(height: 22).padding(2))
    // 将视图挂载到状态栏按钮
    statusItem?.button?.addSubview(hostingView)
    // 配置自动布局
    hostingView.translatesAutoresizingMaskIntoConstraints = false
    // 将宿主视图四边锚定到按钮边界，也就是将视图展开
    hostingView.topAnchor.constraint(equalTo: (statusItem?.button!.topAnchor)!).isActive = true
    hostingView.bottomAnchor.constraint(equalTo: (statusItem?.button!.bottomAnchor)!).isActive = true
    hostingView.leadingAnchor.constraint(equalTo: (statusItem?.button!.leadingAnchor)!).isActive = true
    hostingView.trailingAnchor.constraint(equalTo: (statusItem?.button!.trailingAnchor)!).isActive = true
  }
}
