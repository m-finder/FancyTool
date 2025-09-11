//
//  AppWindow.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//
import SwiftUI

@MainActor
class AppWindow {
  
  private var window: NSWindow!
  
  init(title: String, contentView: some View) {
    
    if window == nil {
      
      let rootView = contentView.frame(
        maxWidth: .infinity
      )
      
      // 配置窗口属性
      window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 440, height: 300),
        styleMask: [.titled, .closable, .miniaturizable],
        backing: .buffered,
        defer: false
      )
      window?.center()
      window?.title = title
      window?.isReleasedWhenClosed = false
      window?.contentView = NSHostingView(rootView: rootView)
      window?.styleMask.remove(.resizable)
    }
  }
  
  public func show(){
    window?.orderFrontRegardless()
    NSApp.activate(ignoringOtherApps: true)
  }
  
}
