//
//  TexterView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import SwiftUI

struct TexterView: View {
  
  @ObservedObject var state = AppState.shared
  @State private var gradientOffset: CGFloat = -1.0
  // 流光
  private let shimmerGradient = Gradient(colors: [.clear, .white.opacity(0.8), .clear])
  private let animation = Animation.linear(duration: 2).repeatForever(autoreverses: false)
  
  // 波浪
  @State private var waveScales: [CGFloat] = []
  @State private var waveAnimationTrigger = false
  private let waveAnimation = Animation.spring(response: 0.15, dampingFraction: 0.4)
  
  var body: some View {
    HStack(spacing: 0) {
      VStack(alignment: .trailing, spacing: 2) {
        if state.showWave {
          HStack(alignment: .firstTextBaseline, spacing: 0) {
            ForEach(Array(state.text.enumerated()), id: \.offset) { index, char in
              Text(String(char))
                .scaleEffect(waveScales.indices.contains(index) ? waveScales[index] : 1.0)
                .animation(
                  waveAnimation.delay(Double(index) * 0.05),
                  value: waveAnimationTrigger
                )
            }
          }
        }else{
          Text(state.text)
        }
      }
    }
    .foregroundStyle(textGradient)
    .overlay(shimmerOverlay)
    .onAppear{
      setupShimmerAnimation()
      setupWaveAnimation()
    }
    .onChange(of: state.showShimmer) {
      withAnimation(nil) { gradientOffset = state.showShimmer ? -1.0 : -1.0 }
      setupShimmerAnimation()
    }
    .onChange(of: state.showWave) {
      withAnimation(nil) { waveScales = Array(repeating: 1.0, count: state.text.count) }
      setupWaveAnimation()
    }
  }
  
  // 文字颜色渐变
  private var textGradient: LinearGradient {
    LinearGradient(
      colors: ColorUtil().getColor(index: state.colorIndex),
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }
  
  // 流光遮罩
  private var shimmerOverlay: some View {
    Group {
      if state.showShimmer {
        GeometryReader { geometry in
          let gradientWidth = geometry.size.width * 0.2
          Rectangle()
            .fill(LinearGradient(
              gradient: shimmerGradient,
              startPoint: .leading,
              endPoint: .trailing
            ))
            .rotationEffect(.degrees(15))
            .frame(width: gradientWidth)
            .offset(x: gradientOffset * (geometry.size.width + gradientWidth))
            .blendMode(.lighten)
        }
        .mask(Text(state.text))
      }
    }
  }
  
  // 流光动画
  private func setupShimmerAnimation() {
    guard state.showShimmer else { return }
    
    DispatchQueue.main.async {
      withAnimation(animation) {
        gradientOffset = 1.0
      }
    }
  }
  
  // 波浪动画
  private func setupWaveAnimation() {
    
    guard state.showWave else { return }
    
    waveScales = Array(repeating: 1.0, count: state.text.count)
    
    let totalDuration: Double = {
      let lastIndex = waveScales.indices.last ?? 0
      return Double(lastIndex) * 0.05 + 0.15 + 1
    }()
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      // 逐个放大字符
      for index in waveScales.indices {
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.05) {
          guard state.showWave else { return }
          withAnimation(waveAnimation) {
            waveScales[index] = 1.5
          }
          
          // 放大后恢复
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guard state.showWave else { return }
            withAnimation(waveAnimation) {
              waveScales[index] = 1.0
            }
          }
        }
      }
    }

    // 重复触发动画
    DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) {
      guard state.showWave else { return }
      
      // 切换trigger状态，触发视图更新
      self.waveAnimationTrigger.toggle()
      // 重新执行动画序列
      self.setupWaveAnimation()
    }
    
  }

}
