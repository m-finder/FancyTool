//
//  Rounder.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/8/23.
//

import AppKit
import Combine

@MainActor
final class Rounder {
  
  static let shared = Rounder()
  
  enum CornerPosition { case topLeft, topRight, bottomLeft, bottomRight }
  
  private struct CornerWindow {
    let window: NSWindow
    let targetFrame: NSRect
  }
  private var windows: [CornerWindow] = []
  private struct ScreenLayout: Equatable {
    let frame: NSRect
    let scale: CGFloat
  }
  private var screenLayout: [CGDirectDisplayID: ScreenLayout] = [:]
  private var cancellables = Set<AnyCancellable>()
  private var remountTask: Task<Void, Never>?
  private var isMounted = false
  
  private init() {}
  
  // MARK: - 挂载
  public func mount() {
    if !isMounted {
      isMounted = true
      setupObservers()
    }
    cancelRemount()
    rebuildWindows()
  }
  
  // MARK: - 卸载
  public func unmount() {
    isMounted = false
    cancelRemount()
    cancellables.removeAll()
    closeWindows()
  }

  private func layout(for screens: [NSScreen]) -> [CGDirectDisplayID: ScreenLayout] {
    Dictionary(uniqueKeysWithValues: screens.compactMap { screen in
      guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return nil }
      return (id, ScreenLayout(frame: screen.frame, scale: screen.backingScaleFactor))
    })
  }

  private func rebuildWindows() {
    let screens = NSScreen.screens
    let layout = layout(for: screens)
    guard layout != screenLayout || windows.count != screens.count * 4 else {
      for corner in windows {
        if corner.window.frame != corner.targetFrame {
          corner.window.setFrame(corner.targetFrame, display: true)
        }
        if !corner.window.isVisible {
          corner.window.orderFrontRegardless()
        }
      }
      return
    }
    closeWindows()
    screens.forEach { createWindows(for: $0) }
    screenLayout = layout
  }

  private func closeWindows() {
    windows.forEach { corner in
      let w = corner.window
      w.orderOut(nil)
      w.contentView = nil
      w.close()
    }
    windows.removeAll()
    screenLayout.removeAll()
  }
  
  // MARK: - 刷新
  public func refresh(_ radius: CGFloat) {
    windows.forEach { corner in
      (corner.window.contentView as? RounderView)?.radius = radius
    }
  }
  
  // MARK: - Observers
  private func setupObservers() {
    // 屏幕参数变化
    NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
      .sink { [weak self] _ in self?.remountAfterDelay() }
      .store(in: &cancellables)
    
    // 空间切换（桌面/全屏）
    NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.activeSpaceDidChangeNotification)
      .sink { [weak self] _ in self?.remountAfterDelay(0.2) }
      .store(in: &cancellables)
    
    // 应用从后台到前台（有时唤醒后先切活跃）
    NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
      .sink { [weak self] _ in self?.remountAfterDelay(0.2) }
      .store(in: &cancellables)
    
    // 睡眠/唤醒
    NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.screensDidSleepNotification)
      .merge(with: NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification))
      .sink { [weak self] _ in self?.cancelRemount() }
      .store(in: &cancellables)

    NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.screensDidWakeNotification)
      .sink { [weak self] _ in self?.remountAfterDelay(0.3, retryAfterWake: true) }
      .store(in: &cancellables)
    
    // 作为兜底：系统唤醒
    NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
      .sink { [weak self] _ in self?.remountAfterDelay(0.3, retryAfterWake: true) }
      .store(in: &cancellables)
  }
  
  private func cancelRemount() {
    remountTask?.cancel()
    remountTask = nil
  }

  private func remountAfterDelay(_ delay: TimeInterval = 0.15, retryAfterWake: Bool = false) {
    guard isMounted else { return }
    if retryAfterWake {
      cancelRemount()
    } else {
      guard remountTask == nil else { return }
    }
    let delays = retryAfterWake ? [delay, 0.7, 1.0, 2.0] : [delay]
    remountTask = Task { [weak self] in
      for delay in delays {
        do {
          try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        } catch { return }
        guard !Task.isCancelled, let self, self.isMounted else { return }
        self.rebuildWindows()
      }
      self?.remountTask = nil
    }
  }
  
  // MARK: - Window creation
  private func createWindows(for screen: NSScreen) {
    let radius = CGFloat(AppState.shared.radius)
    let cornerSize = radius * 2
    let frame = screen.frame
    
    for position in [CornerPosition.topLeft, .topRight, .bottomLeft, .bottomRight] {
      let origin = calculateOrigin(for: position, in: frame, cornerSize: cornerSize)
      let rect = NSRect(origin: origin, size: NSSize(width: cornerSize, height: cornerSize))
      if let window = createWindow(frame: rect, screen: screen, position: position, radius: radius) {
        windows.append(CornerWindow(window: window, targetFrame: rect))
      }
    }
  }
  
  private func calculateOrigin(
    for position: CornerPosition,
    in frame: NSRect,
    cornerSize: CGFloat
  ) -> NSPoint {
    switch position {
    case .topLeft:     return NSPoint(x: frame.minX, y: frame.maxY - cornerSize)
    case .topRight:    return NSPoint(x: frame.maxX - cornerSize, y: frame.maxY - cornerSize)
    case .bottomLeft:  return NSPoint(x: frame.minX, y: frame.minY)
    case .bottomRight: return NSPoint(x: frame.maxX - cornerSize, y: frame.minY)
    }
  }
  
  private func createWindow(
    frame: NSRect,
    screen: NSScreen,
    position: CornerPosition,
    radius: CGFloat
  ) -> NSWindow? {
    let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false, screen: screen)
    
    configureWindow(window, frame: frame)
    
    let view = RounderView(frame: NSRect(origin: .zero, size: frame.size), radius: radius, cornerPosition: position)
    window.contentView = view
    window.orderFrontRegardless()
    return window
  }
  
  private func configureWindow(_ window: NSWindow, frame: NSRect) {
    window.isOpaque = false
    window.backgroundColor = .clear
    window.ignoresMouseEvents = true
    window.hasShadow = false
    window.level = .statusBar
    
    // 跨空间与全屏
    window.collectionBehavior = [
      .canJoinAllSpaces,
      .fullScreenAuxiliary,
      .ignoresCycle,
      .stationary
    ]
    
    window.setFrameOrigin(frame.origin)
    window.isReleasedWhenClosed = false
    window.hidesOnDeactivate = false
  }
}
