//
//  DashedDivider.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/25.
//

import SwiftUI

struct DashedDivider: View {
  
  var color: Color = .gray.opacity(0.2)
  var dashLength: CGFloat = 5
  var dashSpace: CGFloat = 3
  var lineWidth: CGFloat = 1
  var indentSize: CGFloat = 6
  
  var body: some View {
    
    ZStack {
      
      GeometryReader { geometry in
        Path { path in
          path.move(to: CGPoint(x: indentSize, y: 0))
          path.addLine(to: CGPoint(x: geometry.size.width - indentSize, y: 0))
        }
        .strokedPath(StrokeStyle(lineWidth: lineWidth, dash: [dashLength, dashSpace]))
        .foregroundColor(color)
      }
      .frame(height: lineWidth)
      
      HStack {
        Circle().fill(Color.gray).frame(width: indentSize * 2, height: indentSize * 2).offset(x: -indentSize, y: 0)
        Spacer()
        Circle() .fill(Color.gray).frame(width: indentSize * 2, height: indentSize * 2).offset(x: indentSize, y: 0)
      }
      
    }
    .offset(y: -indentSize)
    
  }
}
