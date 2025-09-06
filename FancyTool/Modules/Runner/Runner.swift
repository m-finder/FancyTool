//
//  Runner.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/8/25.
//

import AppKit
import Combine

final class Runner {
  
  static let shared = Runner()
  
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
  private var layer: CALayer?
  private var frameCache: [CGFloat: [CGImage]] = [:]
  private var fps: Double = Config.maxFPS
  
  private var cancellables = Set<AnyCancellable>()
  
  // MARK: - 计算属性
  private var currentScreenScale: CGFloat {
    button?.window?.screen?.backingScaleFactor ??
    NSScreen.main?.backingScaleFactor ?? 2
  }
  
  // MARK: - 当前激活的Runner
  private var currentRunner: RunnerModel? {
    RunnerHandler.shared.getRunnerById(AppState.shared.runnerId)
  }
  
  // MARK: - 挂载
  public func mount(to item: NSStatusItem) {
    self.item = item
    
    guard let button = item.button else { return }
    
    if self.button == nil {
      self.button = button
      setupAnimationLayer()
      observeScreenChanges()
    }
    
    updateDisplay(for: item)
    item.menu = AppMenu.shared.getMenus()
  }
  
  public func refresh() {
    frameCache.removeAll()
    
    // 重新加载新帧
    reloadFrames()
    
    // 刷新显示
    if let item = self.item{
      updateDisplay(for: item)
    }
  }
  
  // MARK: - 刷新速度
  public func refresh(usage: Double) {
    if let item = self.item{
      fps = calculateFPS(from: usage)
      updateDisplay(for: item)
    }
  }
  
  // MARK: - 私有方法
  private func updateDisplay(for item: NSStatusItem) {
    guard let button = button else { return }
    if let runner = currentRunner {
      reloadFrames()
      updateItemSize(item, with: runner)
      applyAnimation(fps: fps)
    } else {
      clearAnimation()
      setDefaultIcon(for: button)
    }
  }
  
  private func setupAnimationLayer() {
    guard let btn = button, btn.layer == nil else { return }
    btn.wantsLayer = true
    
    let layer = CALayer()
    layer.frame = btn.bounds
    layer.contentsGravity = .resizeAspect
    layer.masksToBounds = false
    layer.isOpaque = false
    layer.contentsScale = currentScreenScale
    
    btn.layer?.addSublayer(layer)
    self.layer = layer
  }
  
  private func updateItemSize(_ item: NSStatusItem, with runner: RunnerModel) {
    let frames = frames(for: currentScreenScale)
    let width = frames.first.map(calculateWidth) ?? Config.baseSize
    
    item.length = width
    button?.frame.size.width = width
    layer?.frame = button?.bounds ?? .zero
  }
  
  private func calculateWidth(for image: CGImage) -> CGFloat {
    let ratio = CGFloat(image.width) / CGFloat(image.height)
    return Config.baseSize * ratio
  }
  
  private func calculateFPS(from usage: Double) -> Double {
    return Config.minFPS + (Config.maxFPS - Config.minFPS) * (usage / 100)
  }
  
  // MARK: - 帧处理
  private func frames(for scale: CGFloat) -> [CGImage] {
    if let cached = frameCache[scale] { return cached }
    
    let newFrames = renderFrames(scale: scale)
    frameCache[scale] = newFrames
    return newFrames
  }
  
  private func renderFrames(scale: CGFloat) -> [CGImage] {
    guard let runner = currentRunner else { return [] }
    
    let pixelH = Int(Config.baseSize * scale)
    
    return (0..<runner.frameNumber).compactMap { index in
      let src = runner.getImage(index)
      let ratio = CGFloat(src.width) / CGFloat(src.height)
      let pixelW = Int(round(CGFloat(pixelH) * ratio))
      
      guard let ctx = CGContext(
        data: nil,
        width: pixelW,
        height: pixelH,
        bitsPerComponent: 8,
        bytesPerRow: pixelW * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
      ) else { return nil }
      
      ctx.scaleBy(x: scale, y: scale)
      let drawWidth = CGFloat(pixelH) * ratio / scale
      ctx.draw(src, in: CGRect(x: 0, y: 0, width: drawWidth, height: Config.baseSize))
      
      return ctx.makeImage()
    }
  }
  
  private func reloadFrames() {
    let scale = currentScreenScale
    _ = frames(for: scale)
  }
  
  // MARK: - 动画处理
  private func applyAnimation(fps: Double) {
    guard let layer = layer else { return }
    
    let scale = layer.contentsScale
    let frames = frames(for: scale)
    guard !frames.isEmpty else { return }
    
  
    button?.image = nil
    layer.isHidden = false
    layer.contents = frames.first
    
    let animation = createAnimation(with: frames, fps: fps)
    layer.removeAnimation(forKey: "runner")
    layer.add(animation, forKey: "runner")
  }
  
  private func createAnimation(with frames: [CGImage], fps: Double) -> CAKeyframeAnimation {
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
  
  private func clearAnimation() {
    layer?.removeAnimation(forKey: "runner")
    layer?.isHidden = true
  }
  
  private func setDefaultIcon(for button: NSStatusBarButton) {
    button.image = NSImage(named: Config.defaultIconName)?.resized(to: Config.defaultIconSize)
  }
  
  // MARK: - 屏幕变化监听
  private func observeScreenChanges() {
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
    let newScale = currentScreenScale
    
    frameCache.removeValue(forKey: newScale)
    _ = frames(for: newScale)
    
    layer?.contentsScale = newScale
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
