//
//  PasterFooterView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/26.
//

import SwiftUI

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
  
  var body: some View {
    HStack {
      // 绑定快捷键 (仅显示1-9)
      Text("⌘+\(number)")
        .padding(4)
        .cornerRadius(4)
        .buttonStyle(.plain)
        .font(.system(size: 11))
        .background(Color.gray.opacity(0.2))
      
      Spacer()
      
      // 字符统计
      Text("\(item.content.count) chars").font(.caption).foregroundColor(.secondary)
    }
    .padding(.leading, 10)
    .padding(.trailing, 10)
  }
}
