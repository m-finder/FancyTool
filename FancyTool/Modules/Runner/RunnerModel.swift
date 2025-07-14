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
      kCGImageSourceShouldCache: kCFBooleanTrue as Any,
      // 启用图像变换
      kCGImageSourceCreateThumbnailWithTransform: kCFBooleanTrue as Any,
      // 始终创建缩略图
      kCGImageSourceCreateThumbnailFromImageAlways: kCFBooleanTrue as Any,
      // 设置缩略图最大像素尺寸
      kCGImageSourceThumbnailMaxPixelSize: 200
    ]
  }
  
  // 获取CGImageSource
  private func getCGImageSource(_ data: Data?) -> CGImageSource? {
    guard let rawData = data else { return nil }
    return CGImageSourceCreateWithData(rawData as CFData, getImageOptions() as CFDictionary)
  }
  
  // 按帧获取图像
  func getImage(_ index: Int) -> CGImage {
    
    // 确保索引有效
    var safeIndex = index
    if safeIndex >= frameNumber || safeIndex < 0 {
      safeIndex = 0
    }
    
    guard let imgSrc = getCGImageSource(data),
          let cgImage = CGImageSourceCreateImageAtIndex(imgSrc, safeIndex, getImageOptions() as CFDictionary) else {
      return Self.defaultImage
    }

    return cgImage
  }
}
