//
//  Runner.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/8/25.
//

import AppKit
import Combine

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

// MARK: - 默认的runner图标
class DefaultRunner {
  
  public static var shared = DefaultRunner()
  private let size: CGFloat = 28
  
  public func mount(item: NSStatusItem) {
    guard let button = item.button else { return }
    item.length = size
    button.image = NSImage(named: "m-finder")?.resized(to: size)
  }
}

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
  private var fps: Double = Config.maxFPS
  private var cancellables = Set<AnyCancellable>()
  
  // MARK: - 当前激活的Runner
  public var runner: RunnerModel? {
    RunnerHandler.shared.getRunnerById(AppState.shared.runnerId)
  }
 
  // MARK: - 计算属性，当前屏幕的缩放比例
  private var currentScale: CGFloat {
    button?.window?.screen?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
  }

  init(){
    observe()
  }
  
  deinit {
    cancellables.removeAll()
  }
  
  // MARK: - 挂载
  public func mount(to item: NSStatusItem) {
    self.item = item
    self.button = item.button

    // 载入挂载的图片
    reload()
    // 挂载菜单
    item.menu = AppMenu.shared.getMenus()
  }

  // MARK: - 刷新挂载的图片
  private func reload() {

    guard let item = self.item, let button = self.button else { return }

    // 有 runner
    if RunnerFrame.shared.runner != nil {
      // 挂载动画layer
      RunnerLayer.shared.mount(button: button, scale: currentScale)
      // 加载图片帧
      _ = RunnerFrame.shared.refresh(for: currentScale)
      
      // 刷新图片帧
      let frames = RunnerFrame.shared.refresh(for: currentScale)
      let width = frames.first.map(refresh) ?? Config.baseSize

      item.length = width
      button.frame.size.width = width
      RunnerLayer.shared.layer?.frame = button.bounds
      
      animation()
      return
    }

    // 卸载动画 layer
    RunnerLayer.shared.unmount()
    // 刷新为默认图标和尺寸
    DefaultRunner.shared.mount(item: item)
  }
  
  // MARK: - 刷新选中的runner
  public func refresh() {
    RunnerLayer.shared.layer?.contents = nil
    RunnerFrame.shared.cache.removeAll()
    reload()
  }
  
  // MARK: - 刷新播放速度
  public func refresh(usage: Double) {
    self.fps = Config.minFPS + (Config.maxFPS - Config.minFPS) * (usage / 100)
    reload()
  }
  
  // MARK: - 刷新图片尺寸
  private func refresh(for image: CGImage) -> CGFloat {
    let ratio = CGFloat(image.width) / CGFloat(image.height)
    return Config.baseSize * ratio
  }

  // MARK: - 动画处理
  private func animation(){
    guard let layer = RunnerLayer.shared.layer else { return }
    
    let scale = layer.contentsScale
    let frames = RunnerFrame.shared.refresh(for: scale)
    guard !frames.isEmpty else { return }
    
    button?.image = nil
    layer.isHidden = false
    
    // 把 frame 跟按钮当前 bounds 对齐，防止图片宽度不撑开
    layer.frame = button?.bounds ?? .zero
    
    layer.contents = frames.first
    
    let duration = Double(frames.count) / self.fps
    let animation = CAKeyframeAnimation(keyPath: "contents")
    
    animation.values = frames
    animation.keyTimes = (0..<frames.count).map {
      NSNumber(value: Double($0) / Double(frames.count))
    }
    animation.duration = duration
    animation.repeatCount = .infinity
    animation.calculationMode = .discrete
    animation.isRemovedOnCompletion = false
    layer.removeAnimation(forKey: "runner")
    layer.add(animation, forKey: "runner")
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
    animation()
  }
}


