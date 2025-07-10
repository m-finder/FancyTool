//
//  AboutView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/9.
//

import SwiftUI

struct AboutView: View {
  
  struct CreditItem {
    let name: String
    let license: String
    let url: String?
    let description: String?
  }
  
  private var credits: [CreditItem] = [
    CreditItem(
      name: "Tiny Swords",
      license: "MIT",
      url: "https://pixelfrog-assets.itch.io/tiny-swords",
      description: "Spanish Deck"
    ),
    CreditItem(
      name: "Pirate Bomb",
      license: "CC0",
      url: "https://pixelfrog-assets.itch.io/pirate-bomb",
      description: "Spanish Deck"
    ),
  ]
  
  var body: some View {
    VStack(alignment: .center, spacing: 10){
      
      Text("Acknowledgments").font(.footnote).fontWeight(.heavy).padding(.top, 20)
      
      ForEach(credits, id: \.name) { item in
        VStack(alignment: .leading, spacing: 5) {
          
          // 名称和许可证
          HStack(alignment: .center, spacing: 15) {
            Text(item.name).font(.subheadline)
            
            Text(item.license)
              .font(.footnote)
              .fontWeight(.light)
              .foregroundColor(.white)
              .padding(.horizontal, 5)
              .padding(.vertical, 3)
              .background(Color.blue.opacity(0.7))
              .cornerRadius(4)
          }
          
          // 描述文本
          if let description = item.description {
            Text(description).font(.subheadline).foregroundColor(.secondary)
          }
          
          // 链接（如果有）
          if let urlString = item.url, let url = URL(string: urlString) {
            Link(urlString, destination: url).font(.caption).foregroundColor(.blue).padding(.top, 2)
          }
        }
        .padding(.all, 5)
      }
      
      // 版权
      FancyToolView()
      
    }
    
  }

}


struct AboutView_Previews: PreviewProvider {
  static var previews: some View {
    AboutView()
  }
}
