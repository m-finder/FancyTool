//
//  TexterView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import SwiftUI

struct TexterView: View {
  
  private var colorUtil: ColorUtil = ColorUtil()
  @ObservedObject var state = AppState.shared
  
  var body: some View {
    HStack(spacing: 4) {
      VStack(alignment: .trailing, spacing: -2) {
        if state.colorIndex == 0 {
          Text(AppState.shared.text)
        } else {
          Text(AppState.shared.text).foregroundStyle(LinearGradient(
            colors: colorUtil.getColor(index: state.colorIndex),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ))
        }
      }
    }.padding(2)
  }
}
