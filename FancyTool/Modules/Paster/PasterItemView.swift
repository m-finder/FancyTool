//
//  PasterItemView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/25.
//

import SwiftUI

struct PasterItemView: View {
  
  let item: PasterModel
  let shortcutNumber: Int
  var indexMap: [Int: Int] = [0: 1, 1: 0]
  @ObservedObject var state = AppState.shared
  @State private var isHovering: UUID?
  
  var body: some View {
    
    VStack(spacing: 0){
      
      PasterHeaderView(item: item)
        .background(LinearGradient(
          colors: ColorUtil.shared.getColor(index: indexMap[state.colorIndex] ?? state.colorIndex),
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ))
      
      VStack(alignment: .leading, spacing: 0){
        Text(item.content).fontWeight(.light)
      }
      .padding(.leading, 10)
      .padding(.trailing, 10)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      
      DashedDivider().padding(.horizontal, 0)
      
      PasterFooterView(item: item, number: shortcutNumber)
      
    }
    .cornerRadius(15)
    .overlay(
      RoundedRectangle(cornerRadius: 15).stroke(
        LinearGradient(
          colors: ColorUtil.shared.getColor(index: indexMap[state.colorIndex] ?? state.colorIndex),
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ),
        lineWidth: 2
      )
    )
    .overlay(
      RoundedRectangle(cornerRadius: 15).stroke(
        isHovering == item.id ? Color.blue : Color.clear,
        lineWidth: 2
      )
    )
    .onHover { hovering in
      isHovering = hovering ?  item.id : nil
    }
    .onTapGesture {
      Paster.shared.tap(item)
    }
    .background(.white.opacity(0.5))
    .id(item.id)
  }
}
