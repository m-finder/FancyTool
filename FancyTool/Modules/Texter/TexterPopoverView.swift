//
//  TexterPopoverView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import SwiftUI

struct TexterPopoverView: View {
  
  @ObservedObject var state = AppState.shared
  
  var body: some View {
    VStack(alignment: .center) {
      
      Image("default")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 60,height: 60)
        .padding(.top, 15)
      
      // 标题
      Text("Texter")
        .font(.system(size: 24,weight: .semibold,design: .rounded))
        .foregroundStyle(LinearGradient(
          colors: ColorUtil.shared.getColor(index: state.colorIndex),
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ))
      
      
      // 菜单栏文本
      VStack(alignment: .leading) {
        
        Divider()
        
        LabelledDivider(label: String(localized: "MenuBar Text"))
        
        ZStack {
          
          TextField(String(localized: "Input something"), text: state.$text)
            .onChange(of: state.text) {
              if state.text.count > 30 {
                state.text = String(state.text.prefix(30))
              }
            }
            .textFieldStyle(.roundedBorder)
          
        }
      }
      
      // 多彩文字
      VStack{
        
        LabelledDivider(label: String(localized: "Colorful"))
        
        LazyVGrid(
          columns: Array(
            repeating: GridItem(.flexible(minimum: 20), spacing: 10),
            count: 10
          ),
          spacing: 10
        ) {
          
          ForEach(0..<ColorUtil.shared.getColors().count, id: \.self) { index in
            Button {
              state.colorIndex = index
            } label: {
              Image(systemName: state.colorIndex == index ? "checkmark.square.fill" : "square.fill")
                .foregroundStyle(LinearGradient(
                  colors: ColorUtil.shared.getColor(index: index),
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                ))
            }
            .buttonStyle(.plain)
            .frame(width: 20, height: 20)
          }
        }
        .frame(maxWidth: .infinity)
        
      }
      .padding()
    }
  }
}
