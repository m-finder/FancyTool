//
//  TexterView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import SwiftUI

struct TexterView: View {
  
  @ObservedObject var state = AppState.shared
  @State private var isVisible: Bool = false
  
  var body: some View {

    Text(state.text)
      .shimmering(
        active: (state.showShimmer || state.rainbowShimmer) && isVisible,
        rainbow: state.rainbowShimmer
      )
      .foregroundStyle(textGradient)
      .font(Font(TexterFont.resolve(family: state.texterFontFamily, size: CGFloat(state.fontSize))))
      .onAppear {
        isVisible = true
      }
      .onDisappear {
        isVisible = false
      }
  }
  
  // 文字颜色渐变
  private var textGradient: LinearGradient {
    LinearGradient(
      colors: ColorUtil.shared.getColor(index: state.colorIndex),
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }
}
