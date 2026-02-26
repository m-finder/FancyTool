//
//  FancyToolView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import SwiftUI

struct CopyrightView: View {
  
  private let githubURL = URL(string: "https://github.com/FancyTool/FancyToolApp")!
  
  var body: some View {
    HStack {
      Text("© FancyTool by ").font(.footnote).fontWeight(.light)

      Link("M-finder", destination: githubURL).font(.footnote).fontWeight(.light).foregroundColor(.blue)
      
      Text(" 2025").font(.footnote).fontWeight(.light)
    }
    .padding(.top)
    .padding(.bottom)
  }
}

#Preview {
  CopyrightView()
}
