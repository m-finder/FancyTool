//
//  ContentView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import SwiftUI

struct ContentView: View {
  @ObservedObject var colorModel: ColorModel = ColorModel()
  
  var body: some View {
    Text("FancyTool")
      .foregroundStyle(LinearGradient(
        colors: colorModel.getColor(index: 1),
        startPoint: .topLeading,
        endPoint: .bottomTrailing)
      )
  }
}

#Preview {
  ContentView()
}
