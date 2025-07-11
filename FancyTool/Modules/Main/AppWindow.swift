//
//  AppWindow.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//
import SwiftUI

class AppWindow {
  
  private var window: NSWindow!
  
  init(title: String, contentView: some View) {
    
    if window == nil {
      
      let rootView = ScrollView {
        contentView.frame(
          maxWidth: .infinity
        )
      }.frame(
        width: 440,
        height: 500
      )
      
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
      
      window?.styleMask.remove(.resizable)
      window?.minSize = NSSize(width: 425, height: 800)
      window?.maxSize = NSSize(width: 425, height: 800)
    }
    
    window?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }
  
}
