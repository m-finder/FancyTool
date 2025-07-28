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
  @State private var isHovering: UUID?
  
  var body: some View {
    
    VStack {
      
      PasterHeaderView(item: item)
      
      VStack(alignment: .leading, spacing: 0){
        Text(item.content).fontWeight(.light)
      }
      .padding(.leading, 10)
      .padding(.trailing, 10)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      
      DashedDivider().padding(.horizontal, 0)
      
      PasterFooterView(item: item, number: shortcutNumber)
      
    }
    .topBorder(height: 4, color: ColorUtil().getPasterColor(index: shortcutNumber))
    .overlay(
      RoundedRectangle(cornerRadius: 8).stroke(
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
    .background(.white.opacity(0.2))
    .cornerRadius(15)
    .id(item.id)
  }
}
