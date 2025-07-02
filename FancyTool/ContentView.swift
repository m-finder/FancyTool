//
//  ContentView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import SwiftUI

struct ContentView: View {
  @ObservedObject var colorUtil: ColorUtil = ColorUtil()
  
  var body: some View {
    Text("FancyTool")
      .foregroundStyle(LinearGradient(
        colors: colorUtil.getColor(index: 12),
        startPoint: .topLeading,
        endPoint: .bottomTrailing)
      )
  }
}

#Preview {
  ContentView()
}
