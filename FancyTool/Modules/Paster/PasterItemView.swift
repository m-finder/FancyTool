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
        if let textContent = item.content, !textContent.isEmpty {
          Text(textContent)
            .lineSpacing(5)
            .fontWeight(.light)
        }
        
        if let imageData = item.image, !imageData.isEmpty {
          if let nsImage = NSImage(data: imageData) {
            HStack {
              Spacer()
              Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
              Spacer()
            }
            .padding(.vertical, 4)
          }
        }
      }
      .padding(10)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      
      DashedDivider().padding(.horizontal, 0)
      
      PasterFooterView(item: item, number: shortcutNumber)
      
    }
    .background(.white.opacity(0.5))
    .clipShape(RoundedRectangle(cornerRadius: 15))
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
    .id(item.id)
  }
}
