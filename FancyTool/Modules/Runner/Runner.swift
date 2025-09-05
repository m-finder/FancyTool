//
//  Runner.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/8/25.
//

import AppKit

final class Runner {
  
  static let shared = Runner()
  
  private var imageLayer: CALayer?
  private var currentFrames: [CGImage] = []
  private var currentFPS: Double = 60
  
  public var runner: RunnerModel? {
    RunnerHandler.shared.getRunnerById(AppState.shared.runnerId)
  }
  
  // MARK: - 取 Retina 帧
  // MARK: - 计算 22 pt 高度下的动态宽度
  /// 返回：在 22 pt 高度下，按帧原始宽高比换算出的宽度（pt）
  private func calcDynamicWidth(for image: CGImage) -> CGFloat {
    let pixelH = image.height
    let pixelW = image.width
    let ratio  = CGFloat(pixelW) / CGFloat(pixelH)
    return 22.0 * ratio
  }
  
  // MARK: - 取 Retina 帧（改造版）
  private func reloadFrames() {
    guard let runner = runner else { currentFrames.removeAll(); return }
    
    let scale = NSScreen.main?.backingScaleFactor ?? 2.0
    // 先清空，防止数组里混着不同尺寸
    currentFrames.removeAll(keepingCapacity: true)
    
    for idx in 0..<runner.frameNumber {
      let src = runner.getImage(idx)
      
      let pixelW = Int(22 * scale)
      let pixelH = Int(22 * scale)
      // 建 bitmap
      let colorSpace = CGColorSpaceCreateDeviceRGB()
      let ctx = CGContext(
        data: nil,
        width: pixelW,
        height: pixelH,
        bitsPerComponent: 8,
        bytesPerRow: pixelW * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
      )!
      ctx.scaleBy(x: scale, y: scale)
      // 画的时候按原始比例画，高度 22 pt，宽度自动
      let drawH = 22.0
      let drawW = calcDynamicWidth(for: src)
      let originX = 0.0
      let originY = 0.0
      ctx.draw(src, in: CGRect(x: originX, y: originY, width: drawW, height: drawH))
      if let im = ctx.makeImage() {
        currentFrames.append(im)
      }
    }
  }
  
  // MARK: - 挂载（改造版）
  func mount(to item: NSStatusItem) {
    guard let btn = item.button else { return }
    
    reloadFrames()
    
    // 用第一帧算出宽度
    let firstWidth = currentFrames.first.map(calcDynamicWidth(for:)) ?? 22
    item.length = firstWidth
    btn.frame = NSRect(x: 0, y: 0, width: firstWidth, height: 22)
    
    let layer = CALayer()
    layer.frame = btn.bounds
    layer.contentsGravity = .center
    btn.wantsLayer = true
    btn.layer?.addSublayer(layer)
    imageLayer = layer
    
    applyAnimation(fps: currentFPS)
    item.menu = AppMenu.shared.getMenus()
  }
  
  // MARK: - 刷新速度
  func refresh(for item: NSStatusItem, usage: Double) {
    reloadFrames()
    
    // 重新计算宽度
    let newWidth = currentFrames.first.map(calcDynamicWidth(for:)) ?? 22
    item.length = newWidth
    item.button?.frame = NSRect(x: 0, y: 0, width: newWidth, height: 22)

    let fps = 5 + 55 * (usage / 100)
    print("fps \(fps)")
    applyAnimation(fps: fps)
  }
  
  private func applyAnimation(fps: Double) {
    guard let layer = imageLayer, !currentFrames.isEmpty else { return }
    let duration = Double(currentFrames.count) / fps
    
    let anim = CAKeyframeAnimation(keyPath: "contents")
    anim.values    = currentFrames
    anim.keyTimes  = (0..<currentFrames.count).map {
      NSNumber(value: Double($0) / Double(currentFrames.count))
    }
    anim.duration  = duration
    anim.repeatCount = .infinity
    anim.calculationMode = .discrete
    anim.isRemovedOnCompletion = false
    
    layer.removeAnimation(forKey: "cpu")
    layer.add(anim, forKey: "cpu")
  }
}
