//
//  RunnerModel.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/2.
//

import Foundation
import SwiftData
import AppKit
import CoreGraphics

@Model
class RunnerModel {
  
  @Attribute(.unique) var id: UUID
  var type: String
  var frame_number: Int
  var data: Data
  
  // 初始化
  init(id: UUID, type: String, frame_number: Int, data: Data) {
    self.id = id
    self.type = type
    self.frame_number = frame_number
    self.data = data
  }
}
