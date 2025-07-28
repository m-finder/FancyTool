//
//  TopBorder.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/26.
//

import SwiftUI

struct TopBorder: ViewModifier {
  
  var height: CGFloat
  var color: Color
  var padding: CGFloat = 0
  
  func body(content: Content) -> some View {
    content
      .overlay(
        Rectangle()
          .fill(color)
          .frame(height: height)
          .padding(.horizontal, padding)
          .frame(maxHeight: .infinity, alignment: .top)
      )
  }
  
  
}


extension View {
    func topBorder(height: CGFloat, color: Color, padding: CGFloat = 0) -> some View {
        self.modifier(TopBorder(height: height, color: color, padding: padding))
    }
}
