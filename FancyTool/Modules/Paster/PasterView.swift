//
//  PasterView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/21.
//

import SwiftUI

struct PasterView: View {
  
  @ObservedObject var paster = Paster.shared
  @State private var currentPage = 0
  @State private var eventMonitor: Any?
  private let itemsPerPage = 5
  
  // 计算总页数
  private var pageCount: Int {
    (paster.history.count + itemsPerPage - 1) / itemsPerPage
  }
  
  private func currentPageItemsForPage(_ page: Int) -> [String] {
    let start = page * itemsPerPage
    let end = min(start + itemsPerPage, paster.history.count)
    return Array(paster.history[start..<end])
  }
  
  private func handleKeyDownEvent(_ event: NSEvent) -> NSEvent? {
      // tab键处理
      if event.keyCode == 48 {
          currentPage = (currentPage + 1) % pageCount
          return nil
      }
      
      // Command + 数字键处理 (1-5)
      if event.modifierFlags.contains(.command),
         let char = event.characters,
         let number = Int(char),
         (1...5).contains(number) {
        
          let items = currentPageItemsForPage(currentPage)
          let index = number - 1
          
          // 确保当前页有足够的项目
          if index < items.count {
              Paster.shared.tap(items[index])
          }
          return nil
      }

      // 不处理的事件原样返回
      return event
  }
  
  var body: some View {
    
    if paster.history.isEmpty {
      
      Text(String(localized: "No paste history available.")).frame(width: 300, height: 250)
      
    } else {
      
      VStack(spacing: 15) {
        // 分页内容区域
        ScrollViewReader { proxy in
          
          ScrollView(.horizontal, showsIndicators: false) {
            
            HStack(spacing: 0) {
             
              ForEach(0..<pageCount, id: \.self) { pageIndex in
                HStack(spacing: 15) {
                  ForEach(Array(currentPageItemsForPage(pageIndex).enumerated()), id: \.element) { index, item in
                    HistoryItemView(
                      item: item,
                      shortcutNumber: index + 1
                    ).frame(
                      width: 300,
                      height: 250
                    )
                  }
                }.frame(
                  width: NSScreen.main?.frame.width
                ).padding(.horizontal, 20)
                  .id(pageIndex)
              }
            }
          }.onChange(of: currentPage) {
            // 页面切换添加动画效果
            withAnimation {
              proxy.scrollTo(currentPage, anchor: .leading)
            }
          }
        }
        
        // 自定义分页指示器
        HStack(spacing: 6) {
          
          if pageCount > 1 {
            Text(String(localized: "Tab key switch.")).font(.caption)
          }
          
          ForEach(0..<pageCount, id: \.self) { index in
            Circle().fill(index == currentPage ? Color.blue : Color.gray.opacity(0.5))
              .frame(
                width: 8,
                height: 8
              ).onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                  currentPage = index
                }
              }
          }
        }
      }.onAppear {
        currentPage = 0
        // 快捷键监听
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {  (event: NSEvent) -> NSEvent? in
          return handleKeyDownEvent(event)
        }
      }.onDisappear {
        if let monitor = eventMonitor {
          NSEvent.removeMonitor(monitor)
          eventMonitor = nil
        }
      }.padding(.vertical, 25)
    }
  }
}

struct HistoryItemView: View {
  
  let item: String
  private let itemId = UUID()
  let shortcutNumber: Int
  @State private var isHovering: UUID?

  var body: some View {
    VStack {
      // 文本显示
      ScrollView {
        Text(item).padding(10)
      }.frame(maxWidth: .infinity, maxHeight: .infinity)
      
      HStack {
        // 绑定快捷键 (仅显示1-9)
        Text("⌘\(shortcutNumber)")
          .padding(4)
          .cornerRadius(4)
          .buttonStyle(.plain)
          .font(.system(size: 11))
          .background(Color.gray.opacity(0.2))
        
        Spacer()
        
        // 字符统计
        Text("\(item.count) chars").font(.caption).foregroundColor(.secondary)
      }
      
    }.overlay(
      RoundedRectangle(cornerRadius: 8).stroke(
        isHovering == itemId ? Color.blue : Color.clear,
        lineWidth: 2
      )
    ).onHover { hovering in
      isHovering = hovering ? itemId : nil
    }.onTapGesture {
      Paster.shared.tap(item)
    }.background(Color.gray.opacity(0.2))
      .cornerRadius(8)
      .id(itemId)
  }
}
