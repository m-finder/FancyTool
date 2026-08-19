//
//  PasterModel.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/26.
//
import AppKit
import SwiftData
import Foundation

@Model
class PasterModel: Equatable {
  
  var id = UUID()
  var content: String?
  // 图片通常远大于文本。使用外部存储让 SwiftData 在未访问图片时不把
  // 二进制内容装入 SQLite/进程内缓存；列表优先读取缩略图。
  @Attribute(.externalStorage) var image: Data?
  @Attribute(.externalStorage) var thumbnail: Data? = nil
  var imageWidth: Double? = nil
  var imageHeight: Double? = nil
  var icon: String
  var createdAt: Date
  var isPinned: Bool = false
  
  // 初始化
  init(content: String, icon: String) {
    self.content = content
    self.icon = icon
    self.createdAt = Date()
  }
  
  // 初始化
  init(image: Data, icon: String) {
    self.image = image
    self.icon = icon
    self.createdAt = Date()
    if let nsImage = NSImage(data: image) {
      self.imageWidth = Double(nsImage.size.width)
      self.imageHeight = Double(nsImage.size.height)
      self.thumbnail = nsImage.thumbnailData(maxDimension: 320)?.data
    }
  }
  
  // 自定义相等性判断
  static func == (lhs: PasterModel, rhs: PasterModel) -> Bool {
    // 如果是文本内容，判断文本是否相同
    if let lhsText = lhs.content, let rhsText = rhs.content {
      return lhsText == rhsText
    }
    
    // 图片列表使用缩略图和尺寸去重，避免每次剪贴板轮询都读取所有历史原图。
    // 原图使用外部存储；直接比较 image 会让全部历史图片重新驻留内存。
    else if let lhsThumbnail = lhs.thumbnail, let rhsThumbnail = rhs.thumbnail {
      return lhsThumbnail == rhsThumbnail &&
        lhs.imageWidth == rhs.imageWidth &&
        lhs.imageHeight == rhs.imageHeight
    }
    
    // 类型不同不相等
    else {
      return false
    }
  }
}
