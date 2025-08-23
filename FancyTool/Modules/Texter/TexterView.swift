//
//  TexterView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import SwiftUI

struct TexterView: View {
  
  @ObservedObject var state = AppState.shared
  
  var body: some View {
    Text(state.text).foregroundStyle(textGradient)
  }
  
  // 文字颜色渐变
  private var textGradient: LinearGradient {
    LinearGradient(
      colors: ColorUtil().getColor(index: state.colorIndex),
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }
}
