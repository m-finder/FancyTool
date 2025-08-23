//
//  Rounder.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/8/23.
//

import Foundation
import SwiftUI

class Rounder {
  
  static let shared = Rounder()
  var windows: [NSWindow] = []
  @Published var state = AppState.shared
  
  public func mount() {
    self.unmount()
    
    let screens:[NSScreen] = NSScreen.screens
    
    for screen in screens {
      
      let screenFrame = screen.frame
      
      let window: NSWindow = NSWindow(
        contentRect: screen.frame,
        styleMask: .borderless,
        backing: .buffered,
        defer: false,
        screen: screen
      )
      window.isReleasedWhenClosed = false
      window.isOpaque = false
      window.backgroundColor = NSColor.clear
      window.alphaValue = 1
      window.hasShadow = false
      window.ignoresMouseEvents = true
      window.collectionBehavior = [.stationary, .ignoresCycle, .canJoinAllSpaces, .fullScreenAuxiliary]
      
      let contentView = RounderView(
        frame: NSRect(origin: .zero, size: screenFrame.size),
        radius: state.radius
      )
      window.contentView = contentView
      
      window.setFrameOrigin(screenFrame.origin)
      window.orderFrontRegardless()
      window.level = .screenSaver
      window.orderFront(self)
      
      windows.append(window)
    }
  }
  
  public func unmount() {
    for window in windows {
      window.close()
    }
    windows.removeAll()
  }
  
  public func refresh() {
    for window in windows {
      guard let contentView = window.contentView as? RounderView else { continue }
      contentView.radius = state.radius
      // 触发视图重绘
      contentView.setNeedsDisplay(contentView.bounds)
    }
  }
}
