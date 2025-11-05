//
//  PasterView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/21.
//

import SwiftUI

@MainActor
struct PasterView: View {
  
  @ObservedObject var paster = Paster.shared
  @State private var currentPage: Int = 0
  @State private var eventMonitor: Any?
  
  // 常量
  private enum constant {
    static let limit: Int = 5
    static let padding: CGFloat = 45
    static let spacing: CGFloat = 15
    static let height: CGFloat = 250
  }

  // 屏幕宽度
  private var screenWidth: CGFloat {
    NSScreen.main?.frame.width ?? 1920
  }
  
  // 可用内容宽度
  private var contentWidth: CGFloat {
    screenWidth - (constant.padding * 2)
  }
  
  // 每个项目的宽度计算
  private var itemWidth: CGFloat {
    let totalSpacing = CGFloat(constant.limit - 1) * constant.spacing
    return (contentWidth - totalSpacing) / CGFloat(constant.limit)
  }
  
  // 计算总页数
  private var totalPage: Int {
    (paster.history.count + constant.limit - 1) / constant.limit
  }
  
  // 取出当前页数据
  private func rows(_ page: Int) -> [PasterModel] {
    let start = page * constant.limit
    let end = min(start + constant.limit, paster.history.count)
    return Array(paster.history[start..<end])
  }
  
  // 快捷键监听
  private func onAppear(){
    currentPage = 0
    // 快捷键监听
    eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {  (event: NSEvent) -> NSEvent? in
      
      // esc 键监听
      if event.keyCode == 53 {
        Paster.shared.hide()
        return nil
      }
      
      // tab 键监听
      if event.keyCode == 48 {
        currentPage = (currentPage + 1) % totalPage
        return nil
      }
      
      // Command + 数字键处理 (1-5)
      if event.modifierFlags.contains(.command),
         let char = event.characters,
         let number = Int(char),
         (1...5).contains(number) {
        
        let items = rows(currentPage)
        let index = number - 1
        
        // 确保当前页有足够的项目
        if index < items.count {
          Paster.shared.tap(items[index])
        }
        return nil
      }
      
      return event
    }
  }
  
  // 隐藏事件，取消按键监听
  private func onDisappear(){
    if let monitor = eventMonitor {
      NSEvent.removeMonitor(monitor)
      eventMonitor = nil
    }
  }

  // MARK: - 空页面
  private func emptyView() -> some View {
    return Text(String(localized: "No paste history available.")).frame(height: constant.height)
  }
  
  // MARK: - 内容页面
  private func contentView() -> some View {
    return VStack(spacing: 15) {
      
      ScrollViewReader { proxy in
        
        ScrollView(.horizontal, showsIndicators: false) {
          
          HStack(spacing: 0) {
            
            ForEach(0..<totalPage, id: \.self) { pageIndex in
              HStack(spacing: constant.spacing) {
                ForEach(Array(rows(pageIndex).enumerated()), id: \.element) { index, item in
                  PasterItemView(
                    item: item,
                    shortcutNumber: index + 1
                  )
                  .frame(width: itemWidth, height: constant.height)
                }
              }
              .frame(width: contentWidth)
              .id(pageIndex)
              
            }
          }
        }
        .onChange(of: currentPage) {
          withAnimation {
            proxy.scrollTo(currentPage, anchor: .leading)
          }
        }
      }
      
      // 自定义分页指示器
      PageIndicator(total: totalPage, current: $currentPage)
    }
    .padding(.horizontal, constant.padding)
    .padding(.vertical, 25)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onAppear(perform: onAppear)
    .onDisappear(perform: onDisappear)
  }
  
  var body: some View {
    
    if paster.history.isEmpty {
      emptyView()
    } else {
      contentView()
    }
  }
}


