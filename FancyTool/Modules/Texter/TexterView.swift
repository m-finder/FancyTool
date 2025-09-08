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
  @State private var isVisible: Bool = false
  
  var body: some View {
    
//    Text(state.text)
//      .foregroundStyle(textGradient)
//      .shimmering(active: state.showShimmer && isVisible, rainbow: state.rainbowShimmer)
//      .onAppear {
//        isVisible = true
//        gradientColors = ColorUtil().getColor(index: state.colorIndex)
//      }
//      .onDisappear {
//        isVisible = false
//      }
//      .onChange(of: state.colorIndex) {
//        gradientColors = ColorUtil.shared.getColor(index: state.colorIndex)
//      }
    LayerShimmerText(
      text: state.text,
      font: .systemFont(ofSize: 13, weight: .medium),
      baseColor: NSColor(ColorUtil.shared.getColor(index: state.colorIndex).first ?? .white),
      active: state.showShimmer,           // 恢复 active 控制
      rainbow: state.rainbowShimmer,       // 恢复 rainbow 控制
      bandSize: 0.35,
      duration: 3.0,
      gradientColors: nil
    )
    .frame(minWidth: 40, idealWidth: 80, maxWidth: .infinity, minHeight: 18, maxHeight: 22)
    .padding(.horizontal, 5)
    
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
