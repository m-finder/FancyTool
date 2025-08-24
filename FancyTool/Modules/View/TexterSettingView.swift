//
//  TexterSettingView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/25.
//

import SwiftUI

struct TexterSettingView: View {
  
  @ObservedObject var state = AppState.shared
  
  var body: some View {
    
    VStack(alignment: .center, spacing: 0) {
      
      // 第一个 Toggle
      HStack {
        Text(String(localized: "Shimmer"))
          .font(.system(size: 12))
          .frame(width: 50, alignment: .trailing) // 固定宽度并右对齐
        
        Toggle("", isOn: state.$showShimmer)
          .onChange(of: state.showShimmer) { _, newValue in
            state.showShimmer = newValue
            if !newValue {
              state.rainbowShimmer = newValue
            }
          }
          .toggleStyle(SwitchToggleStyle())
      }
      .padding()
      
      // 第二个 Toggle
      HStack {
        Text(String(localized: "Rainbow Shimmer"))
          .font(.system(size: 12))
          .frame(width: 50, alignment: .trailing) // 固定宽度并右对齐
        
        Toggle("", isOn: state.$rainbowShimmer)
          .onChange(of: state.rainbowShimmer) { _, newValue in
            state.rainbowShimmer = newValue
          }
          .toggleStyle(SwitchToggleStyle())
      }
      .padding()
      
    }
    .frame(maxHeight: .infinity, alignment: .top)
  }
}

#Preview {
  TexterSettingView()
}
