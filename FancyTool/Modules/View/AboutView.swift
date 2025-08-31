//
//  AboutView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/9.
//

import SwiftUI

struct AboutView: View {
  
  var body: some View {
    
    VStack(alignment: .center, spacing: 10){
      
      // 自画像
      Image("m-finder")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 60, height: 60)
        .padding(.top, 15)
      
      Text("Coding is life, life is fancy.").padding()
      
      // 版权
      CopyrightView()
      
    }
    
  }
  
}


struct AboutView_Previews: PreviewProvider {
  static var previews: some View {
    AboutView()
  }
}
