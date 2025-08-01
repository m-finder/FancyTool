//
//  PasterModel.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/26.
//
import SwiftData
import Foundation

@Model
class PasterModel: Equatable {
  
  var id = UUID()
  var content: String?
  var image: Data?
  var icon: String
  var craetedAt: Date
  
  // 初始化
  init(content: String, icon: String) {
    self.content = content
    self.icon = icon
    self.craetedAt = Date()
  }
  
  // 初始化
  init(image: Data, icon: String) {
    self.image = image
    self.icon = icon
    self.craetedAt = Date()
  }
  
  // 自定义相等性判断
  static func == (lhs: PasterModel, rhs: PasterModel) -> Bool {
    // 如果是文本内容，判断文本是否相同
    if let lhsText = lhs.content, let rhsText = rhs.content {
      return lhsText == rhsText
    }
    
    // 如果是图片内容，判断图片数据是否相同
    else if let lhsImage = lhs.image, let rhsImage = rhs.image {
      return lhsImage == rhsImage
    }
    
    // 类型不同（一个是文本一个是图片）则不相等
    else {
      return false
    }
  }
}
