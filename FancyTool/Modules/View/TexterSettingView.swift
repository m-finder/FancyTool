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
   
      HStack {
        Text(String(localized: "Shimmer"))
          .font(.system(size: 12))
          .frame(width: 50, alignment: .trailing)
        
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
      
      HStack {
        Text(String(localized: "Rainbow Shimmer"))
          .font(.system(size: 12))
          .frame(width: 50, alignment: .trailing)
        
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
