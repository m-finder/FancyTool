//
//  PasterPageIndicator.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/26.
//

import SwiftUI

struct PageIndicator: View {
  
  private let total: Int
  @Binding private var current: Int
  
  public init(total: Int, current: Binding<Int>){
    self.total = total
    self._current = current
  }
  
  var body: some View {
    
    HStack(spacing: 6) {
      
      if total > 1 {
        Text(String(localized: "Tab key switch.")).font(.caption)
      }
      
      ForEach(0..<total, id: \.self) { index in
        Circle().fill(index == current ? Color.blue : Color.gray.opacity(0.5))
          .frame(width: 8,height: 8)
          .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
              current = index
            }
          }
      }
      
    }
    
  }
}
