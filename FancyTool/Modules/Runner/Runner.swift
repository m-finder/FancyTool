//
//  Runner.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/8/25.
//

import AppKit
import Combine

final class Runner {
  
  public static let shared = Runner()
  
  // MARK: - 配置常量
  private enum Config {
    static let baseSize: CGFloat = 22
    static let minFPS: Double = 5
    static let maxFPS: Double = 60
    static let defaultIconName = "m-finder"
    static let defaultIconSize: CGFloat = 28
  }
  
  // MARK: - 属性
  private weak var item: NSStatusItem?
  private weak var button: NSStatusBarButton?
//  private var cache: [CGFloat: [CGImage]] = [:]
  private var fps: Double = Config.maxFPS
  
  private var cancellables = Set<AnyCancellable>()

  // MARK: - 计算属性
  private var currentScale: CGFloat {
    button?.window?.screen?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
  }

  
  // MARK: - 挂载
  public func mount(to item: NSStatusItem) {
    
    guard let button = item.button else { return }
    
    if self.button == nil {
      self.item = item
      self.button = button
      // 挂载动画layer
      RunnerLayer.shared.mount(button: button, scale: currentScale)
      // 添加屏幕和窗口监听
      observe()
    }
    
    // 刷新挂载的图片
    refresh(for: item)
    
    item.menu = AppMenu.shared.getMenus()
  }
  
  // MARK: - 刷新选中的runner
  public func refresh() {
    guard let item = self.item else { return }
  
    if RunnerFrame.shared.runner == nil {
      RunnerLayer.shared.layer?.contents = nil
    }
    
    RunnerFrame.shared.cache.removeAll()
    refresh(for: item)
  }
  
  // MARK: - 刷新播放速度
  public func refresh(usage: Double) {
    guard let item = self.item else { return }
    
    fps = refresh(from: usage)
    refresh(for: item)
  }
  
  // MARK: - 刷新挂载的图片
  private func refresh(for item: NSStatusItem) {
    
    guard let button = self.button else { return }
    
    if let runner = RunnerFrame.shared.runner {
      // 加载图片帧
      _ = RunnerFrame.shared.refresh(for: currentScale)
      updateItemSize(item, with: runner)
      applyAnimation(fps: fps)
      return
    }
    
    // 卸载动画 layer
    RunnerLayer.shared.unmount()
    // 刷新为默认图标和尺寸
    refresh(item: item, button: button)
  }
  

  private func updateItemSize(_ item: NSStatusItem, with runner: RunnerModel) {
    let frames = RunnerFrame.shared.refresh(for: currentScale)
    let width = frames.first.map(refresh) ?? Config.baseSize
    
    item.length = width
    button?.frame.size.width = width
    RunnerLayer.shared.layer?.frame = button?.bounds ?? .zero
  }
  
  // MARK: - 刷新图片尺寸
  private func refresh(for image: CGImage) -> CGFloat {
    let ratio = CGFloat(image.width) / CGFloat(image.height)
    return Config.baseSize * ratio
  }
  
  // MARK: - 刷新 fps
  private func refresh(from usage: Double) -> Double {
    return Config.minFPS + (Config.maxFPS - Config.minFPS) * (usage / 100)
  }
  
  // MARK: - 刷新为默认图标和尺寸
  private func refresh(item: NSStatusItem, button: NSStatusBarButton) {
    item.length = Config.defaultIconSize
    button.image = NSImage(named: Config.defaultIconName)?.resized(to: Config.defaultIconSize)
  }

  // MARK: - 动画处理
  private func applyAnimation(fps: Double) {
    guard let layer = RunnerLayer.shared.layer else { return }
    
    let scale = layer.contentsScale
    let frames = RunnerFrame.shared.refresh(for: scale)
    guard !frames.isEmpty else { return }
    
    button?.image = nil
    layer.isHidden = false
    
    // 把 frame 跟按钮当前 bounds 对齐，防止图片宽度不撑开
    layer.frame = button?.bounds ?? .zero
    
    layer.contents = frames.first
    
    let animation = setAnimation(with: frames, fps: fps)
    layer.removeAnimation(forKey: "runner")
    layer.add(animation, forKey: "runner")
  }
  
  // MARK: - 设置动画
  private func setAnimation(with frames: [CGImage], fps: Double) -> CAKeyframeAnimation {
    let duration = Double(frames.count) / fps
    let animation = CAKeyframeAnimation(keyPath: "contents")
    
    animation.values = frames
    animation.keyTimes = (0..<frames.count).map {
      NSNumber(value: Double($0) / Double(frames.count))
    }
    animation.duration = duration
    animation.repeatCount = .infinity
    animation.calculationMode = .discrete
    animation.isRemovedOnCompletion = false
    
    return animation
  }
  
  // MARK: - 屏幕变化监听
  private func observe() {
    NotificationCenter.default
      .publisher(for: NSApplication.didChangeScreenParametersNotification)
      .sink { [weak self] _ in
        self?.handleScreenChanged()
      }
      .store(in: &cancellables)
    
    if let window = button?.window {
      NotificationCenter.default
        .publisher(for: NSWindow.didChangeScreenNotification, object: window)
        .sink { [weak self] _ in
          self?.handleScreenChanged()
        }
        .store(in: &cancellables)
    }
  }
  
  private func handleScreenChanged() {
    let newScale = currentScale
    
    RunnerFrame.shared.cache.removeValue(forKey: newScale)
    _ = RunnerFrame.shared.refresh(for: newScale)
    
    RunnerLayer.shared.layer?.contentsScale = newScale
    applyAnimation(fps: fps)
  }
}

// MARK: - NSImage 扩展
private extension NSImage {
  func resized(to size: CGFloat) -> NSImage {
    let newImage = NSImage(size: NSSize(width: size, height: size))
    newImage.lockFocus()
    draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    newImage.unlockFocus()
    return newImage
  }
}
