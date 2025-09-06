//
//  Rounder.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/8/23.
//

import AppKit
import Combine

final class Rounder {
  
  static let shared = Rounder()
  
  // MARK: - 类型定义
  enum CornerPosition {
    case topLeft, topRight, bottomLeft, bottomRight
  }
  
  // MARK: - 属性
  private var windows: [NSWindow] = []
  private var cancellables = Set<AnyCancellable>()
  
  // MARK: - 初始化
  private init() {
    setupScreenChangeObserver()
  }
  
  deinit {
    cancellables.removeAll()
  }
  
  // MARK: - 公开方法
  public func mount() {
    unmount()
    NSScreen.screens.forEach { createWindows(for: $0) }
  }
  
  public func unmount() {
    windows.forEach { window in
      window.orderOut(nil)
      window.contentView = nil
      window.close()
    }
    windows.removeAll()
  }
  
  public func refresh(_ radius: CGFloat) {
    windows.forEach { win in
      (win.contentView as? RounderView)?.radius = radius
    }
  }
  
  // MARK: - 私有方法
  private func setupScreenChangeObserver() {
    NotificationCenter.default
      .publisher(for: NSApplication.didChangeScreenParametersNotification)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.mount()
      }
      .store(in: &cancellables)
  }
  
  private func createWindows(for screen: NSScreen) {
    let radius = AppState.shared.radius
    let cornerSize = radius * 2
    let frame = screen.frame
    
    let cornerPositions: [CornerPosition] = [.topLeft, .topRight, .bottomLeft, .bottomRight]
    
    cornerPositions.forEach { position in
      let origin = calculateOrigin(for: position, in: frame, cornerSize: cornerSize)
      let rect = NSRect(origin: origin, size: NSSize(width: cornerSize, height: cornerSize))
      
      if let window = createWindow(frame: rect, screen: screen, position: position, radius: radius) {
        windows.append(window)
      }
    }
  }
  
  private func calculateOrigin(for position: CornerPosition, in frame: NSRect, cornerSize: CGFloat) -> NSPoint {
    switch position {
    case .topLeft:
      return NSPoint(x: frame.minX, y: frame.maxY - cornerSize)
    case .topRight:
      return NSPoint(x: frame.maxX - cornerSize, y: frame.maxY - cornerSize)
    case .bottomLeft:
      return NSPoint(x: frame.minX, y: frame.minY)
    case .bottomRight:
      return NSPoint(x: frame.maxX - cornerSize, y: frame.minY)
    }
  }
  
  private func createWindow(frame: NSRect, screen: NSScreen, position: CornerPosition, radius: CGFloat) -> NSWindow? {
    let window = NSWindow(
      contentRect: frame,
      styleMask: .borderless,
      backing: .buffered,
      defer: false,
      screen: screen
    )
    
    configureWindow(window, frame: frame)
    
    let view = RounderView(
      frame: NSRect(origin: .zero, size: frame.size),
      radius: radius,
      cornerPosition: position
    )
    
    window.contentView = view
    window.orderFront(nil)
    
    return window
  }
  
  private func configureWindow(_ window: NSWindow, frame: NSRect) {
    window.isOpaque = false
    window.backgroundColor = .clear
    window.ignoresMouseEvents = true
    window.hasShadow = false
    window.level = .statusBar
    window.collectionBehavior = [.stationary, .ignoresCycle]
    window.setFrameOrigin(frame.origin)
    window.isReleasedWhenClosed = false
  }
  
  private func updateAllWindows(with radius: CGFloat) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      
      self.windows.forEach { window in
        if let view = window.contentView as? RounderView {
          view.radius = radius
        }
      }
    }
  }
}
