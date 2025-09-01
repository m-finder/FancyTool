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

  private init() {
    // 监听屏幕变化
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleScreenChange),
      name: NSApplication.didChangeScreenParametersNotification,
      object: nil
    )
  }
  
  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  
  // MARK: - 延迟执行以确保系统完成屏幕配置更新
  @IBAction private func handleScreenChange(_ notification: Notification) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
      self?.mount()
    }
  }
  
  // MARK: - Public Methods
  public func mount() {
    unmount()
    
    for screen in NSScreen.screens {
      createWindow(for: screen)
    }
  }
  
  public func unmount() {
    windows.forEach { $0.close() }
    windows.removeAll()
  }
  
  public func refresh() {
    for window in windows {
      guard let contentView = window.contentView as? RounderView else { continue }
      contentView.radius = AppState.shared.radius
      contentView.setNeedsDisplay(contentView.bounds)
    }
  }
  
  // MARK: - Helper Methods
  private func createWindow(for screen: NSScreen) {
    let window = NSWindow(
      contentRect: screen.frame,
      styleMask: .borderless,
      backing: .buffered,
      defer: false,
      screen: screen
    )
    
    configure(window: window)
    setupContentView(for: window, screen: screen)
    
    window.orderFrontRegardless()
    windows.append(window)
  }
  
  private func configure(window: NSWindow) {
    window.isReleasedWhenClosed = false
    window.isOpaque = false
    window.backgroundColor = .clear
    window.alphaValue = 1
    window.hasShadow = false
    window.ignoresMouseEvents = true
    window.collectionBehavior = [.stationary, .ignoresCycle, .canJoinAllSpaces, .fullScreenAuxiliary]
    window.level = .screenSaver
  }
  
  private func setupContentView(for window: NSWindow, screen: NSScreen) {
    let contentView = RounderView(
      frame: NSRect(origin: .zero, size: screen.frame.size),
      radius: AppState.shared.radius
    )
    window.contentView = contentView
  }
}

