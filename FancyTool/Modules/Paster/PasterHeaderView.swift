//
//  PasterFooterView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/26.
//

import SwiftUI

@MainActor
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
        Text(DateUtil.shared.relativeTime(from: item.createdAt)).font(.footnote)
      }
      .foregroundStyle(.white)
      .fontWeight(.light)
      
      Spacer()
      
      if item.icon != "Unknown" {
        Image(nsImage: getAppIcon(from: item.icon)).resizable().frame(width: 32, height: 32)
      } else {
        Image("default").frame(width: 32, height: 32).foregroundColor(.secondary)
      }

      Button(
        action: {
          Paster.shared.togglePin(item)
        },
        label: {
          Image(systemName: item.isPinned ? "pin.circle.fill" : "pin.circle")
            .foregroundColor(item.isPinned ? .yellow : .secondary)
            .background(Color.white.opacity(0.8))
            .clipShape(Circle())
        }
      )
      .buttonStyle(PlainButtonStyle())
      .help(String(localized: item.isPinned ? "Unpin" : "Pin"))
      .zIndex(1)
      .frame(width: 24, height: 24)
      .contentShape(Circle())
      
      Button(
        action: {
          DispatchQueue.main.async {
            Paster.shared.remove(item)
          }
        },
        label: {
          Image(systemName: "xmark.circle.fill")
            .foregroundColor(.red)
            .background(Color.white.opacity(0.8))
            .clipShape(Circle())
        }
      )
      .buttonStyle(PlainButtonStyle())
      .zIndex(1)
      .frame(width: 24, height: 24)
      .contentShape(Circle())
      
    }
    .padding(.leading, 15)
    .padding(.trailing, 15)
    .frame(maxWidth: .infinity, minHeight: 42, maxHeight: 42)
  }
}
