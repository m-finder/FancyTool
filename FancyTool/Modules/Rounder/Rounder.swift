//
//  Rounder.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/8/23.
//

import SwiftUI

class Rounder {
  
  public static let shared = Rounder()
  private var windows: [NSWindow] = []
  private var observer: NSObjectProtocol?
  
  enum CornerPosition {
    case topLeft, topRight, bottomLeft, bottomRight
  }
  
  private init() {
    observer = NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification,
      object: NSApplication.shared,
      queue: .main
    ) {_ in }
  }
  
  deinit {
    if let ob = observer {
      NotificationCenter.default.removeObserver(ob)
    }
    unmount()
  }
  
  // MARK: - 挂载
  public func mount() {
    unmount()
    
    let screens = NSScreen.screens
    for screen in screens {
      windows(for: screen)
    }
  }

  // MARK: - 取消挂载
  public func unmount() {
    windows.forEach { $0.close() }
    windows.removeAll()
  }
  
  // MARK: - 刷新尺寸
  public func refresh() {
    let newRadius = AppState.shared.radius
    for window in windows {
      guard let contentView = window.contentView as? RounderView else { continue }
      contentView.radius = newRadius
    }
  }
  
  // MARK: - 为单个屏幕添加4个角落窗口
  private func windows(for screen: NSScreen) {
    let radius = AppState.shared.radius
    let cornerSize = radius * 2
    let screenFrame = screen.frame
    
    // 四个角落的位置配置
    let corners: [(position: CornerPosition, origin: NSPoint)] = [
      (.topLeft, NSPoint(x: screenFrame.minX, y: screenFrame.maxY - cornerSize)),
      (.topRight, NSPoint(x: screenFrame.maxX - cornerSize, y: screenFrame.maxY - cornerSize)),
      (.bottomLeft, NSPoint(x: screenFrame.minX, y: screenFrame.minY)),
      (.bottomRight, NSPoint(x: screenFrame.maxX - cornerSize, y: screenFrame.minY))
    ]
    
    for (position, origin) in corners {
      let window = corner(
        frame: NSRect(origin: origin, size: NSSize(width: cornerSize, height: cornerSize)),
        screen: screen,
        position: position,
        radius: radius
      )
      windows.append(window)
    }
  }

  // MARK: - 创建单个角落窗口
  private func corner(
    frame: NSRect,
    screen: NSScreen,
    position: CornerPosition,
    radius: CGFloat
  ) -> NSWindow {
    
    let window = NSWindow(
      contentRect: frame,
      styleMask: .borderless,
      backing: .buffered,
      defer: false,
      screen: screen
    )
    
    // 窗口属性优化
    window.isOpaque = false
    window.backgroundColor = .clear
    window.ignoresMouseEvents = true
    window.hasShadow = false
    window.level = .statusBar
    window.collectionBehavior = [.stationary, .ignoresCycle]
    window.setFrameOrigin(frame.origin)
    
    // 设置内容视图
    let contentView = RounderView(
      frame: NSRect(origin: .zero, size: frame.size),
      radius: radius,
      cornerPosition: position
    )
    window.contentView = contentView
    window.orderFront(nil)
    return window
  }
}


