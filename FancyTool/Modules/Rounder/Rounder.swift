//
//  Rounder.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/8/23.
//

import Foundation
import SwiftUI
import AppKit

class Rounder {
  
  static let shared = Rounder()
  var windows: [NSWindow] = []
  @Published var state = AppState.shared
  // 存储通知观察者，用于后续移除
  private var screenChangeObserver: NSObjectProtocol?
  
  private init() {
    // 初始化时注册屏幕变化通知监听
    setupScreenChangeObservation()
  }
  
  deinit {
    // 释放时移除通知监听
    if let observer = screenChangeObserver {
      NotificationCenter.default.removeObserver(observer)
    }
  }
  
  private func setupScreenChangeObservation() {
    // 使用更兼容的屏幕参数变化通知
    screenChangeObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification,
      object: NSApplication.shared,
      queue: .main
    ) { [weak self] _ in
      // 延迟执行以确保系统完成屏幕配置更新
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
      contentView.setNeedsDisplay(contentView.bounds)
    }
  }
}

