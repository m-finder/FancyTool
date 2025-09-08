//
//  RunnerFrame.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/9/7.
//

import SwiftUI

class RunnerFrame {
  
  public static var shared = RunnerFrame()
  
  // MARK: - 配置常量
  private enum Config {
    static let baseSize: CGFloat = 22
    static let minFPS: Double = 5
    static let maxFPS: Double = 60
    static let defaultIconName = "m-finder"
    static let defaultIconSize: CGFloat = 28
  }
  
  // MARK: - 当前激活的Runner
  public var runner: RunnerModel? {
    RunnerHandler.shared.getRunnerById(AppState.shared.runnerId)
  }
  
  // MARK: - 计算属性
//  private var currentScale: CGFloat {
//    button?.window?.screen?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
//  }
  
  // MARK: - 图片帧缓存
  public var cache: [CGFloat: [CGImage]] = [:]
  
  // MARK: - 刷新图片帧尺寸
  public func refresh(for scale: CGFloat) -> [CGImage] {
    if let cached = cache[scale] { return cached }
    
    let newFrames = handle(scale: scale)
    cache[scale] = newFrames
    return newFrames
  }
  
//  // MARK: - 刷新挂载的图片
//  private func refresh(for item: NSStatusItem) {
//    
//    guard let button = item.button else { return }
//    
//    if let runner = self.runner {
//      // 加载图片帧
//      _ = RunnerFrame.shared.refresh(for: currentScale)
//      updateItemSize(item, with: runner)
//      applyAnimation(fps: fps)
//      return
//    }
//    
//    // 卸载动画 layer
//    RunnerLayer.shared.unmount()
//    // 刷新为默认图标和尺寸
//    refresh(item: item, button: button)
//  }
  
//  private func updateItemSize(_ item: NSStatusItem, with runner: RunnerModel) {
//    guard let button = item.button else { return }
//    
//    let frames = RunnerFrame.shared.refresh(for: currentScale)
//    let width = frames.first.map(refresh) ?? Config.baseSize
//    
//    item.length = width
//    button.frame.size.width = width
//    RunnerLayer.shared.layer?.frame = button.bounds
//  }
//  
//  // MARK: - 刷新为默认图标和尺寸
//  private func refresh(item: NSStatusItem, button: NSStatusBarButton) {
//    item.length = Config.defaultIconSize
//    button.image = NSImage(named: Config.defaultIconName)?.resized(to: Config.defaultIconSize)
//  }
  
  // MARK: - 处理帧数据
  private func handle(scale: CGFloat) -> [CGImage] {
    
    guard let runner = runner else { return [] }
    
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
  
}
