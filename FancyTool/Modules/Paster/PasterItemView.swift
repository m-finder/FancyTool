//
//  PasterItemView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/25.
//

import SwiftUI

@MainActor
struct PasterItemView: View {
  
  let item: PasterModel
  let shortcutNumber: Int
  @ObservedObject var state = AppState.shared
  @State private var isHovering = false

  private var accentGradient: LinearGradient {
    LinearGradient(colors: ColorUtil.shared.getColor(index: state.colorIndex),
                   startPoint: .topLeading, endPoint: .bottomTrailing)
  }
  
  var body: some View {
    
    VStack(spacing: 0){
      
      PasterHeaderView(item: item)
        .background(accentGradient)
      
      VStack(alignment: .leading, spacing: 0){
        
        if let textContent = item.content, !textContent.isEmpty {
          Text(textContent).lineSpacing(5).fontWeight(.light)
        }
        
        if let imageData = item.thumbnail ?? item.image, !imageData.isEmpty {
          if let nsImage = NSImage(data: imageData) {
            
            HStack {
              Spacer()
              Image(nsImage: nsImage).resizable().aspectRatio(contentMode: .fit)
              Spacer()
            }
            .padding(.vertical, 4)
            
          }
        }
        
      }
      .padding(10)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      
      DashedDivider()
      
      PasterFooterView(item: item, number: shortcutNumber)
      
    }
    .background(Color(.controlBackgroundColor).opacity(0.2))
    .clipShape(RoundedRectangle(cornerRadius: 15))
    .overlay(
      RoundedRectangle(cornerRadius: 15).stroke(
        accentGradient,
        lineWidth: 2
      )
    )
    .overlay(
      RoundedRectangle(cornerRadius: 15).stroke(
        isHovering ? Color.blue : Color.clear,
        lineWidth: 2
      )
    )
    .onHover { isHovering = $0 }
    .onTapGesture {
      Paster.shared.tap(item)
    }
    .id(item.id)
  }
}
