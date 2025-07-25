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
    
    VStack(alignment: .center, spacing: 0){
      
      Toggle(
        String(localized: "Shimmer"),
        isOn: state.$showShimmer
      ).onChange(of: state.showShimmer) { _, newValue in
        state.showShimmer = newValue
      }.toggleStyle(SwitchToggleStyle())
        .font(.system(size: 12))
        .padding()
      
    }.frame(maxHeight: .infinity, alignment: .top)
  }
}

#Preview {
  TexterSettingView()
}
