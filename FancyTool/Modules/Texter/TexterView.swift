//
//  TexterView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import SwiftUI

struct TexterView: View {
  
  @ObservedObject var state = AppState.shared
  @State private var gradientColors: [Color] = []
  
  var body: some View {
    Text(state.text)
      .foregroundStyle(textGradient)
      .shimmering(active: state.showShimmer, rainbow: state.rainbowShimmer)
      .onAppear {
        gradientColors = ColorUtil().getColor(index: state.colorIndex)
      }
      .onChange(of: state.colorIndex) {
        gradientColors = ColorUtil().getColor(index: state.colorIndex)
      }
  }
  
  // 文字颜色渐变
  private var textGradient: LinearGradient {
    LinearGradient(
      colors: gradientColors,
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }
}
