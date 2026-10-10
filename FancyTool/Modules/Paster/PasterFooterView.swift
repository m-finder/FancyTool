//
//  PasterFooterView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/26.
//

import SwiftUI

@MainActor
struct PasterFooterView: View {
  
  var number: Int
  var item: PasterModel
  
  init(number: Int, item: PasterModel){
    self.number = number
    self.item = item
  }
  
  init(item: PasterModel, number: Int){
    self.number = number
    self.item = item
  }

  private var imageSize: CGSize {
    guard let imageData = item.thumbnail ?? item.image, !imageData.isEmpty else {
      return .zero
    }
    if let width = item.imageWidth, let height = item.imageHeight {
      return CGSize(width: width, height: height)
    }
    return NSImage(data: imageData)?.size ?? .zero
  }
  
  var body: some View {
    HStack {

      // 绑定快捷键
      Text("⌘+\(number)")
        .padding(4)
        .cornerRadius(4)
        .buttonStyle(.plain)
        .font(.system(size: 11))
      
      Spacer()
      
      // 字符统计
      if let textContent = item.content, !textContent.isEmpty {
        Text("\(textContent.count) \(String(localized: "chars"))")
          .font(.caption)
          .foregroundColor(.secondary)
      }
      
      // 图片尺寸
      if imageSize.width > 0, imageSize.height > 0 {
        Text("\(Int(imageSize.width)) * \(Int(imageSize.height))")
          .font(.caption)
          .foregroundColor(.secondary)
      }
      
    }
    .padding(.leading, 10)
    .padding(.trailing, 10)
  }
}
