//
//  RunnerModel.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/2.
//

import Foundation
import SwiftData
import AppKit


@Model
class RunnerModel {
  
  var id: UUID
  var isDefault: Bool
  var frameNumber: Int
  var data: Data
  
  // 初始化
  init(id: UUID, isDefault: Bool, frameNumber: Int, data: Data) {
    self.id = id
    self.isDefault = isDefault
    self.frameNumber = frameNumber
    self.data = data
  }
  
}

// 扩展图片的相关功能
extension RunnerModel {

  private static var defaultImage = #imageLiteral(resourceName: "AppLogo").cgImage(forProposedRect: nil, context: nil, hints: nil)!
  
  // 获取图像选项
  private func getImageOptions() -> [CFString: Any] {
    [
      kCGImageSourceShouldCache: kCFBooleanTrue as Any
    ]
  }
  
  // 获取CGImageSource
  private func getCGImageSource(_ data: Data?) -> CGImageSource? {
    guard let rawData = data else { return nil }
    return CGImageSourceCreateWithData(rawData as CFData, getImageOptions() as CFDictionary)
  }
  
  private func getRealFrameCount(_ data: Data?) -> Int {
    guard let imageSrc = getCGImageSource(data) else {
      return 0
    }
    
    return CGImageSourceGetCount(imageSrc)
  }
  
  func setGIF(data: Data) -> Bool {
    let num = getRealFrameCount(data)
    
    if num < 0 {
      return false
    }
    
    self.frameNumber = Int(num)
    self.data = data
    return true
  }
  
  // 按帧获取图像
  func getImage(_ index: Int) -> CGImage {
    
    // 确保索引有效
    var safeIndex = index
    if safeIndex >= frameNumber || safeIndex < 0 {
      safeIndex = 0
    }
    
    // 缓存未命中，创建新图像
    guard let imgSrc = getCGImageSource(data),
          let cgImage = CGImageSourceCreateImageAtIndex(imgSrc, safeIndex, getImageOptions() as CFDictionary) else {
      return Self.defaultImage
    }

    return cgImage
  }
  
  static func cleanupCache() {
    // 释放 SwiftData 上下文资源
    let context = ModelContext(RunnerHandler.shared.container)
    context.autosaveEnabled = false
    
    // 清理所有缓存对象
    try? context.delete(model: RunnerModel.self)
    print("Cleared GIF frame cache")
  }
}
