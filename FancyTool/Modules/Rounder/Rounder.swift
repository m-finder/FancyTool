//
//  Rounder.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/8/23.
//

import SwiftUI

class Rounder {
  
  public static let shared = Rounder()
  
  var windows: [NSWindow] = []
  private var observer: NSObjectProtocol?
  
  private init() {
    observation()
  }
  
  deinit {
    if let ob = observer {
      NotificationCenter.default.removeObserver(ob)
    }
  }
  
  private func observation() {
    observer = NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification,
      object: NSApplication.shared,
      queue: .main
    ) { [weak self] _ in
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        self?.mount()
      }
    }
  }
  
  public func mount() {
    
    self.unmount()
    
    let screens: [NSScreen] = NSScreen.screens
    
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
        radius: AppState.shared.radius
      )
      window.contentView = contentView
      window.setFrameOrigin(screenFrame.origin)
      window.level = .statusBar
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
      if let contentView = window.contentView as? RounderView {
        contentView.radius = AppState.shared.radius
        contentView.setNeedsDisplay(contentView.bounds)
      }
    }
  }
}

