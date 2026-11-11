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
    guard let width = item.imageWidth, let height = item.imageHeight else { return .zero }
    return CGSize(width: width, height: height)
  }
  
  var body: some View {
    HStack {

      // 绑定快捷键
      Text(verbatim: "⌘+\(number)")
        .padding(4)
        .cornerRadius(4)
        .buttonStyle(.plain)
        .font(.system(size: 11))
      
      Spacer()
      
      // 字符统计
      if let textContent = item.content, !textContent.isEmpty {
        Text("\(textContent.count) chars")
          .font(.caption)
          .foregroundColor(.secondary)
      }
      
      // 图片尺寸
      if imageSize.width > 0, imageSize.height > 0 {
        Text(verbatim: "\(Int(imageSize.width)) * \(Int(imageSize.height))")
          .font(.caption)
          .foregroundColor(.secondary)
      }
      
    }
    .padding(.leading, 10)
    .padding(.trailing, 10)
  }
}
