//
//  TexterView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import SwiftUI

struct TexterView: View {
  
  private var colorUtil: ColorUtil = ColorUtil()
  @ObservedObject var state = AppState.shared
  @State private var gradientOffset: CGFloat = -1.0
  
  private func animation(){
    if state.showShimmer {
      withAnimation(Animation.linear(duration: 2).repeatForever(autoreverses: false)) {
        gradientOffset = 1.0
      }
    }else{
      gradientOffset = -1.0
    }
  }
  
  var body: some View {
    
    HStack(spacing: 0) {
      VStack(alignment: .trailing, spacing: 2) {
        Text(AppState.shared.text).foregroundStyle(LinearGradient(
          colors: colorUtil.getColor(index: state.colorIndex),
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )).overlay(
          // 光带遮罩层
          Group{
            if state.showShimmer {
              GeometryReader { geometry in
                let gradientWidth = geometry.size.width * 0.2
                Rectangle().fill(
                  LinearGradient(
                    gradient: Gradient(colors: [
                      .clear,
                      .white.opacity(0.8),
                      .clear
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                  )
                ).rotationEffect(.degrees(15))
                  .frame(width: gradientWidth)
                  .offset(x: gradientOffset * (geometry.size.width + gradientWidth))
                  .blendMode(.lighten)
              }.mask(Text(state.text))
            }
          }
        )
      }
    }.onAppear {
      animation()
    }.onChange(of: state.showShimmer) {
      animation()
    }
    
  }
}
