//
//  PasterFooterView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/26.
//

import SwiftUI

struct PasterHeaderView: View {

  var item: PasterModel
  
  init(item: PasterModel){
    self.item = item
  }

  private func getAppIcon(from path: String?) -> NSImage {
    guard let path = path else {
      return NSImage(systemSymbolName: "app", accessibilityDescription: nil)!
    }
    return NSWorkspace.shared.icon(forFile: path)
  }
  
  var body: some View {
    
    HStack{
      
      HStack{
        Text(String(localized: item.content != nil ? "Text" : "Image")).font(.title)
        Text(DateUtil.shared.relativeTime(from: item.craetedAt)).font(.footnote)
      }
      .foregroundStyle(.white)
      .fontWeight(.light)
      
      Spacer()
      
      if item.icon != "Unknown" {
        Image(nsImage: getAppIcon(from: item.icon)).resizable().frame(width: 32, height: 32)
      } else {
        Image("default").frame(width: 32, height: 32).foregroundColor(.secondary)
      }
      
    }
    .padding(.leading, 15)
    .padding(.trailing, 15)
    .frame(maxWidth: .infinity, minHeight: 42, maxHeight: 42)
  }
}
