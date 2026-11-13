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
  var previewColors: [Color]? = nil
  var fitsAvailableWidth = false
  
  var body: some View {
    Text(previewColors != nil && state.text.isEmpty ? String(localized: "Keep happy.") : state.text)
      .shimmering(
        active: (state.showShimmer || state.rainbowShimmer) && isVisible,
        rainbow: state.rainbowShimmer
      )
      .foregroundStyle(textGradient)
      .font(Font(TexterFont.resolve(family: state.fontFamily, size: CGFloat(state.fontSize))))
      .lineLimit(1)
      .minimumScaleFactor(fitsAvailableWidth ? 0.4 : 1)
      .fixedSize(horizontal: !fitsAvailableWidth, vertical: false)
      .frame(minWidth: state.text.isEmpty ? 8 : 0)
      .padding(.horizontal, (state.normalBorder || state.rainbowBorder || state.gradientBackground) ? TexterBorderStyle.horizontalPadding : 0)
      .frame(height: 20)
      .texterBorder(colors: selectedColors,
                    borderColors: ShimmerColors.rainbowPalette.map { Color(nsColor: $0) },
                    plain: state.normalBorder, rainbow: state.rainbowBorder,
                    gradientBackground: state.gradientBackground, clockwise: state.borderClockwise)
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
      colors: selectedColors,
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  private var selectedColors: [Color] {
    previewColors ?? TexterPalette.colors(index: state.colorIndex, customData: state.customColorsData)
  }

}

private struct TexterBorderModifier: ViewModifier {
  let colors: [Color]
  let borderColors: [Color]
  let plain: Bool
  let rainbow: Bool
  let gradientBackground: Bool
  let clockwise: Bool

  func body(content: Content) -> some View {
    content.background {
      if gradientBackground {
        RoundedRectangle(cornerRadius: TexterBorderStyle.cornerRadius)
          .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing).opacity(0.12))
          .allowsHitTesting(false).accessibilityHidden(true)
      }
    }.overlay {
      if rainbow || plain {
        GeometryReader { geometry in
          TexterBorderView(colors: borderColors, rainbow: rainbow, bounds: geometry.size, clockwise: clockwise)
        }
          .allowsHitTesting(false).accessibilityHidden(true)
      }
    }
  }
}

extension View {
  func texterBorder(colors: [Color], borderColors: [Color], plain: Bool, rainbow: Bool,
                    gradientBackground: Bool, clockwise: Bool) -> some View {
    modifier(TexterBorderModifier(colors: colors, borderColors: borderColors, plain: plain, rainbow: rainbow,
                                  gradientBackground: gradientBackground, clockwise: clockwise))
  }
}
