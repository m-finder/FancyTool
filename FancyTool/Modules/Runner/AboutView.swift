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
      name: "Spanish Deck from Jose Angel Canabal",
      license: "Custom License Terms",
      url: "https://jcanabal.itch.io/spanish-deck-pixel-art",
      description: "Spanish Deck"
    ),
    CreditItem(
      name: "Car And Tank",
      license: "CC BY-ND",
      url: "https://bdragon1727.itch.io/car-and-tank-part-8",
      description: "Car And Tank"
    ),
    CreditItem(
      name: "Goldie",
      license: "Custom License Terms",
      url: "https://artoellie.itch.io/adopt-goldie-for-free",
      description: "Goldie"
    ),
    CreditItem(
      name: "PixelNME",
      license: "Custom License Terms",
      url: "https://slimelvl2.itch.io/pixelme-cosplay-02",
      description: "PixelNME"
    ),
  ]
  
  var body: some View {
    
    List {
      // 页面标题
      Section(header: Text("鸣谢").font(.title).bold()) {
        Text("感谢以下资源和贡献者对本应用的支持:")
          .foregroundColor(.secondary)
          .padding(.vertical, 4)
      }.padding(.all, 10)
      
      // 鸣谢列表
      Section {
        ForEach(credits, id: \.name) { item in
          VStack(alignment: .leading, spacing: 6) {
            // 名称和许可证
            HStack {
              Text(item.name).font(.headline)
              
              Spacer()
              
              Text(item.license)
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.blue.opacity(0.7))
                .cornerRadius(4)
            }
            
            // 描述文本
            if let description = item.description {
              Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            
            // 链接（如果有）
            if let urlString = item.url, let url = URL(string: urlString) {
              Link(urlString, destination: url)
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.top, 2)
            }
          }
          .padding(.vertical, 4)
        }
      }
      
      // 底部版权信息
      Section {
        HStack {
          Spacer()
          Text("© \(Calendar.current.component(.year, from: Date())) FancyTool by M-finder 2025")
            .font(.caption)
            .foregroundColor(.secondary)
          Spacer()
        }
        .padding(.vertical, 8)
      }
    }
  }
}


struct AboutView_Previews: PreviewProvider {
  static var previews: some View {
    AboutView()
  }
}
