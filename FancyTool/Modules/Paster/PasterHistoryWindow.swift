//
//  PasterHistoryWindow.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/19.
//

import AppKit
import SwiftUI

@MainActor
class PasterHistoryWindow: NSWindow, NSWindowDelegate{
  
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
    
    let windowHeight: CGFloat = 360
    let windowX: CGFloat = screenFrame.minX
    let windowY: CGFloat = screenFrame.minY
  
    let windowFrame = NSRect(x: windowX, y: windowY, width: screenFrame.width, height: windowHeight)
    
    super.init(contentRect: windowFrame, styleMask: [.borderless, .utilityWindow], backing: .buffered, defer: false)
    
    // 设置窗口样式
    isOpaque = false
    backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.8)
    hasShadow = true
    level = .popUpMenu
    hidesOnDeactivate = true
    
    let sizedContent = contentView.frame(width: screenFrame.width, height: windowHeight)
    if #available(macOS 26.0, *) {
      backgroundColor = .clear
      let container = NSView(frame: NSRect(origin: .zero, size: windowFrame.size))
      container.wantsLayer = true
      container.layer?.backgroundColor = NSColor.clear.cgColor
      container.addSubview(PopupGlassSurface.make(content: sizedContent,
                                                  frame: container.bounds, cornerRadius: 16))
      self.contentView = container
    } else {
      let hostingView = NSHostingView(rootView: sizedContent)
      hostingView.autoresizingMask = [.width, .height]
      self.contentView = hostingView
    }
    self.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
  }
  
}
