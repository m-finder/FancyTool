//
//  Runner.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/8/25.
//

import AppKit

final class Runner {
  
  static let shared = Runner()
  
  private var layer: CALayer?
  private var frames: [CGImage] = []
  private var fps: Double = 60
  private var size: Double = 22.0
  
  public var runner: RunnerModel? {
    RunnerHandler.shared.getRunnerById(AppState.shared.runnerId)
  }
  
  private var statusBar: NSScreen? {
    NSScreen.main
  }
  
  private var isMainScreen: Bool { NSScreen.main == statusBar }
  
  // MARK: - 挂载（改造版）
  public func mount(to item: NSStatusItem) {
    guard let button = item.button else { return }
    
    print("isMainScreen: \(isMainScreen)")
    
    if runner != nil {
      
      let layer = CALayer()
      layer.frame = button.bounds
      button.layer = layer
      self.layer = layer
  
      reloadFrames()
      applyAnimation(fps: fps)
      
    }else {
      if let image = NSImage(named: "m-finder"){
        image.size = NSSize(width: 28, height: 28)
        button.image = image
        button.target = self
      }
    }
    
    item.menu = AppMenu.shared.getMenus()
  }
  
  // MARK: - 刷新播放速度
  public func refresh(for item: NSStatusItem, usage: Double) {
    // 重新计算宽度
    let newWidth = frames.first.map(getWidth(for:)) ?? 22
    item.length = newWidth
    item.button?.frame = NSRect(x: 0, y: 0, width: newWidth, height: 22)

    let fps = 5 + 55 * (usage / 100)
    print("fps \(fps)")
    applyAnimation(fps: fps)
  }
  
  // MARK: - 取 Retina 帧
  private func getWidth(for image: CGImage) -> CGFloat {
    let pixelH = image.height
    let pixelW = image.width
    let ratio  = CGFloat(pixelW) / CGFloat(pixelH)
    return size * ratio
  }
  
  // MARK: - 取 Retina 帧
  private func reloadFrames() {
    
    guard let runner = runner else { frames.removeAll(); return }
    
    let scale = NSScreen.main?.backingScaleFactor ?? 2.0
    for idx in 0..<runner.frameNumber {
      let src = runner.getImage(idx)
      let pixel = Int(size * scale)
      
      // 建 bitmap
      let ctx = CGContext(
        data: nil,
        width: pixel,
        height: pixel,
        bitsPerComponent: 8,
        bytesPerRow: pixel * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
      )!
      ctx.scaleBy(x: scale, y: scale)
      // 画的时候按原始比例画，高度 22 pt，宽度自动
      let drawW = getWidth(for: src)
      let originX = 0.0, originY = 0.0
      
      ctx.draw(src, in: CGRect(x: originX, y: originY, width: drawW, height: size))
      if let im = ctx.makeImage() {
        frames.append(im)
      }
    }
  }
  
 
  private func applyAnimation(fps: Double) {
    guard let layer = self.layer, !frames.isEmpty else { return }
    
    // 动画持续时间
    let duration = Double(frames.count) / fps
    // 动画
    let animation = getAnimation(duration: duration)
    // 重载动画
    layer.removeAnimation(forKey: "runner")
    layer.add(animation, forKey: "runner")
  }
  
  // 生成动画
  private func getAnimation(duration: Double) -> CAKeyframeAnimation{
    let anim = CAKeyframeAnimation(keyPath: "contents")
    anim.values = frames
    anim.keyTimes = (0..<frames.count).map {
      NSNumber(value: Double($0) / Double(frames.count))
    }
    anim.duration  = duration
    anim.repeatCount = .infinity
    anim.calculationMode = .discrete
    anim.isRemovedOnCompletion = false
    return anim
  }
}
