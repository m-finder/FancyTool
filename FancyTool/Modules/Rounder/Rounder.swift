//
//  Rounder.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/8/23.
//

import AppKit

final class Rounder {
  
  static let shared = Rounder()
  
  private var windows: [NSWindow] = []
  private var screenObserver: NSObjectProtocol?
  
  enum CornerPosition {
    case topLeft, topRight, bottomLeft, bottomRight
  }
  
  private init() {
    // 监听屏幕变化事件
    screenObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      // 屏参变化时重挂载
      self?.remount()
    }
  }
  
  deinit {
    if let token = screenObserver {
      NotificationCenter.default.removeObserver(token)
      screenObserver = nil
    }
  }
  
  // MARK: - Public
  public func mount() {
    unmount() // 先卸载，避免重复
    for screen in NSScreen.screens {
      createWindows(for: screen)
    }
  }
  
  public func unmount() {
    let toClose = windows
    windows.removeAll()
    
    for window in toClose {
      window.orderOut(nil)
      window.contentView = nil
      window.delegate = nil
      window.isReleasedWhenClosed = false
      window.close()
    }
  }
  
  private func remount() {
    DispatchQueue.main.async { [weak self] in
      self?.mount()
    }
  }

  public func refresh() {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      let newRadius = AppState.shared.radius
      for window in self.windows {
        if let view = window.contentView as? RounderView {
          view.radius = newRadius
        }
      }
    }
  }
  
  // MARK: - Private
  private func createWindows(for screen: NSScreen) {
    let radius = AppState.shared.radius
    let cornerSize = radius * 2
    let frame = screen.frame
    
    let corners: [(CornerPosition, NSPoint)] = [
      (.topLeft,     NSPoint(x: frame.minX,            y: frame.maxY - cornerSize)),
      (.topRight,    NSPoint(x: frame.maxX - cornerSize, y: frame.maxY - cornerSize)),
      (.bottomLeft,  NSPoint(x: frame.minX,            y: frame.minY)),
      (.bottomRight, NSPoint(x: frame.maxX - cornerSize, y: frame.minY))
    ]
    
    for (position, origin) in corners {
      let rect = NSRect(origin: origin, size: NSSize(width: cornerSize, height: cornerSize))
      let win = makeCornerWindow(frame: rect, screen: screen, position: position, radius: radius)
      windows.append(win)
    }
  }
  
  private func makeCornerWindow(
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
    window.isOpaque = false
    window.backgroundColor = .clear
    window.ignoresMouseEvents = true
    window.hasShadow = false
    window.level = .statusBar
    window.collectionBehavior = [.stationary, .ignoresCycle]
    window.setFrameOrigin(frame.origin)
    
    let view = RounderView(
      frame: NSRect(origin: .zero, size: frame.size),
      radius: radius,
      cornerPosition: position
    )
    window.contentView = view
    window.orderFront(nil)
    return window
  }
}
