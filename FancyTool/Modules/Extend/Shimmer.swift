//
//  Shimmer.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/8/23.
//

import SwiftUI

public struct Shimmer: ViewModifier {

  
  private let animation: Animation
  private let gradient: Gradient
  private let min, max: CGFloat
 
  @State private var isInitialState = true
  @Environment(\.layoutDirection) private var layoutDirection
  
  public init(
    animation: Animation = Self.defaultAnimation,
    gradient: Gradient = Self.defaultGradient,
    bandSize: CGFloat = 0.3
  ) {
    self.animation = animation
    self.gradient = gradient
    self.min = 0 - bandSize
    self.max = 1 + bandSize
  }
  
  public static let defaultAnimation = Animation.linear(duration: 1.5).delay(2).repeatForever(autoreverses: false)
  
  
  public static let defaultGradient = Gradient(colors: [
    .clear,
    .white.opacity(0.8),
    .clear
  ])
  
  public static let rainbowGradient = Gradient(colors: [.clear, .orange, .blue, .green, .clear])
  
  var startPoint: UnitPoint {
    if layoutDirection == .rightToLeft {
      isInitialState ? UnitPoint(x: max, y: min) : UnitPoint(x: 0, y: 1)
    } else {
      isInitialState ? UnitPoint(x: min, y: min) : UnitPoint(x: 1, y: 1)
    }
  }
  
  var endPoint: UnitPoint {
    if layoutDirection == .rightToLeft {
      isInitialState ? UnitPoint(x: 1, y: 0) : UnitPoint(x: min, y: max)
    } else {
      isInitialState ? UnitPoint(x: 0, y: 0) : UnitPoint(x: max, y: max)
    }
  }
  
  public func body(content: Content) -> some View {
    let gradient = LinearGradient(gradient: gradient, startPoint: startPoint, endPoint: endPoint)
    content
      .overlay(gradient.mask(content))
      .animation(animation, value: isInitialState)
      .onAppear {
        withAnimation(animation) {
          isInitialState = false
        }
      }
  }
  
}

public extension View {
  @ViewBuilder func shimmering(
    active: Bool = true,
    rainbow: Bool = true,
    animation: Animation = Shimmer.defaultAnimation,
    bandSize: CGFloat = 0.3
  ) -> some View {
    if active {
      if rainbow {
        modifier(Shimmer(animation: animation, gradient: Shimmer.rainbowGradient, bandSize: bandSize))
      }else{
        modifier(Shimmer(animation: animation, gradient: Shimmer.defaultGradient, bandSize: bandSize))
      }
    } else {
      self
    }
  }
}

