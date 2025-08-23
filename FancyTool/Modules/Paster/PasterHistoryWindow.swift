//
//  PasterHistoryWindow.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/19.
//

import AppKit
import SwiftUI

class PasterHistoryWindow: NSWindow, NSWindowDelegate{
  
  @Published var history = Paster.shared.history
  
  func windowDidResignKey(_ notification: Notification) {
    Paster.shared.hide()
  }
  
  // 明确允许成为关键窗口
  override var canBecomeKey: Bool {
    return true
  }

  init<Content: View>(contentView: Content) {
    let currentScreen = NSScreen.screens.first { screen in
      NSMouseInRect(NSEvent.mouseLocation, screen.frame, false)
    } ?? NSScreen.main ?? NSScreen()
    
    let screenFrame = currentScreen.frame
    
    let windowHeight: CGFloat = 300
    let windowX: CGFloat = screenFrame.minX
    let windowY: CGFloat = screenFrame.minY
  
    let windowFrame = NSRect(x: windowX, y: windowY, width: screenFrame.width, height: windowHeight)
    
    super.init(contentRect: windowFrame, styleMask: [.borderless, .utilityWindow], backing: .buffered, defer: false)
    
    // 设置窗口样式
    isOpaque = false
    hasShadow = false
    level = .popUpMenu
    hidesOnDeactivate = true
    
    // 使用 NSHostingView 包装 SwiftUI View
    let hostingView = NSHostingView(
      rootView: contentView.frame(
        width: screenFrame.width,
        height: windowHeight
      )
    )
    hostingView.autoresizingMask = [.width, .height]
    
    // 设置内容视图
    self.contentView = hostingView
    self.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
  }
  
}
