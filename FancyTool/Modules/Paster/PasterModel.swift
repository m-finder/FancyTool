//
//  PasterModel.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/26.
//
import SwiftData
import Foundation

@Model
class PasterModel {
  
  var id = UUID()
  var content: String
  var icon: String
  var craetedAt: Date
  
  // 初始化
  init(content: String, icon: String) {
    self.content = content
    self.icon = icon
    self.craetedAt = Date()
  }
}
