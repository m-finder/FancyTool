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
  
  private let size: CGFloat = 22
  private var fps: Double = 60
  
  // MARK: - 图层 & 帧缓存
  private weak var button: NSStatusBarButton?
  private var animationLayer: CALayer?
  private var framesByScale: [CGFloat: [CGImage]] = [:]
  

  // MARK: - 外部只读
  private var runner: RunnerModel? {
    RunnerHandler.shared.getRunnerById(AppState.shared.runnerId)
  }
  
  // MARK: - 挂载
  func mount(to item: NSStatusItem) {
    guard let btn = item.button else { return }
    
    if button == nil {
      button = btn
      setupAnimationLayer()
    }
    
    // 根据 runner 有无决定样式
    if runner != nil {
      reloadFramesIfNeeded()
      applyAnimation(fps: fps)
    } else {
      // 无 runner → 静态图标
      animationLayer?.removeFromSuperlayer()
      animationLayer = nil
      btn.image = NSImage(named: "m-finder")?.with(size: 28)
    }
    
    item.menu = AppMenu.shared.getMenus()
  }
  
  // MARK: - 刷新速度
  func refresh(for item: NSStatusItem, usage: Double) {
    // 计算新 fps
    fps = 5 + 55 * (usage / 100)
    
    // 重新计算宽度
    let scale = currentScreenScale
    let frames = frames(for: scale)
    let newWidth = frames.first.map(widthFor(image:)) ?? size
    item.length = newWidth
    btn?.frame.size.width = newWidth
    
    // 同步子图层大小
    animationLayer?.frame = btn?.bounds ?? .zero
    
    // 重启动画
    applyAnimation(fps: fps)
  }
  
  // MARK: - 私有：子图层
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
    animationLayer = layer
  }
  
  // MARK: - 私有：帧缓存 / 渲染
  private func frames(for scale: CGFloat) -> [CGImage] {
    if let cached = framesByScale[scale] { return cached }
    let new = renderFrames(scale: scale)
    framesByScale[scale] = new
    return new
  }
  
  private func renderFrames(scale: CGFloat) -> [CGImage] {
    guard let runner = runner else { return [] }
    
    let pixelH = Int(size * scale)
    let frames = (0..<runner.frameNumber).compactMap { idx -> CGImage? in
      let src = runner.getImage(idx)
      let ratio = CGFloat(src.width) / CGFloat(src.height)
      let pixelW = Int(round(CGFloat(pixelH) * ratio))
      
      guard let ctx = CGContext(
        data: nil,
        width: pixelW,
        height: pixelH,
        bitsPerComponent: 8,
        bytesPerRow: pixelW * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
      else { return nil }
      
      ctx.scaleBy(x: scale, y: scale)
      let drawW = CGFloat(pixelH) * ratio / scale   // pt 单位
      ctx.draw(src, in: CGRect(x: 0, y: 0, width: drawW, height: size))
      return ctx.makeImage()
    }
    return frames
  }
  
  private func reloadFramesIfNeeded() {
    let scale = currentScreenScale
    _ = frames(for: scale)
  }
  
  // MARK: - 私有：动画
  private func applyAnimation(fps: Double) {
    guard let layer = animationLayer else { return }
    let scale = layer.contentsScale
    let frames = frames(for: scale)
    guard !frames.isEmpty else { return }
    
    // 兜底：先放一帧，避免空白
    layer.contents = frames.first
    
    let duration = Double(frames.count) / fps
    let anim = CAKeyframeAnimation(keyPath: "contents")
    anim.values = frames
    anim.keyTimes = (0..<frames.count).map { NSNumber(value: Double($0) / Double(frames.count)) }
    anim.duration = duration
    anim.repeatCount = .infinity
    anim.calculationMode = .discrete
    anim.isRemovedOnCompletion = false
    
    layer.removeAnimation(forKey: "runner")
    layer.add(anim, forKey: "runner")
  }
  
  // MARK: - 私有：屏幕变化
  private var currentScreenScale: CGFloat {
    button?.window?.screen?.backingScaleFactor
    ?? NSScreen.main?.backingScaleFactor
    ?? 2
  }

  private func handleScreenChanged() {
    let newScale = currentScreenScale
    animationLayer?.contentsScale = newScale
    reloadFramesIfNeeded()
    applyAnimation(fps: fps)
  }
  
  // MARK: - 工具
  private var btn: NSStatusBarButton? { button }
  
  private func widthFor(image: CGImage) -> CGFloat {
    let ratio = CGFloat(image.width) / CGFloat(image.height)
    return size * ratio
  }
}

// MARK: - NSImage 缩放辅助
private extension NSImage {
  func with(size: CGFloat) -> NSImage {
    let new = NSImage(size: .init(width: size, height: size))
    new.lockFocus()
    draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    new.unlockFocus()
    return new
  }
}
