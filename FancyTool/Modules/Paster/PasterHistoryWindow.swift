//
//  PasterHistoryWindow.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/19.
//

import AppKit
import SwiftUI

class PasterHistoryWindow: NSWindow{
  
  @Published var history = Paster.shared.history
  // 明确允许成为关键窗口
  override var canBecomeKey: Bool {
    return true
  }
  
  init<Content: View>(contentView: Content) {
    let screenFrame = NSScreen.main?.frame ?? NSRect()
    let windowHeight: CGFloat = 300
    let windowFrame = NSRect(x: 0, y: 0, width: screenFrame.width, height: windowHeight)
    
    super.init(contentRect: windowFrame, styleMask: [.borderless], backing: .buffered, defer: false)
    
    // 设置窗口样式
    backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.9)
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
    hostingView.frame = contentLayoutRect
    
    // 设置内容视图
    self.contentView = hostingView
  }
  
}
