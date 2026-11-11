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
  @State private var searchText = ""
  @State private var filteredHistory: [PasterModel] = []
  @FocusState private var isSearching: Bool
  
  // 常量
  private enum constant {
    static let limit: Int = 5
    static let padding: CGFloat = 45
    static let spacing: CGFloat = 15
    static let height: CGFloat = 250
  }

  // 屏幕宽度
  private var screenWidth: CGFloat {
    paster.window?.screen?.frame.width ?? NSScreen.main?.frame.width ?? 1920
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
    (filteredHistory.count + constant.limit - 1) / constant.limit
  }

  private func refreshResults(_ history: [PasterModel]) {
    let query = PasterSearch.Query(searchText)
    filteredHistory = query.isEmpty ? history : history.filter {
      query.matches(content: $0.content, sourceAppPath: $0.icon)
    }
    currentPage = min(currentPage, max(0, totalPage - 1))
  }
  
  // MARK: - 取出当前页数据
  private func rows(_ page: Int) -> [PasterModel] {
    let records = filteredHistory
    return Array(records[PasterSearch.pageRange(page: page, count: records.count, pageSize: constant.limit)])
  }
  
  // MARK: - 快捷键监听
  private func onAppear(){
    currentPage = 0
    isSearching = true
    guard eventMonitor == nil else { return }
    // 快捷键监听
    eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {  (event: NSEvent) -> NSEvent? in
      
      // esc 键监听
      if event.keyCode == 53 {
        Paster.shared.hide()
        return nil
      }
      
      // tab 键监听
      if event.keyCode == 48, totalPage > 0 {
        let direction = event.modifierFlags.contains(.shift) ? -1 : 1
        currentPage = (currentPage + direction + totalPage) % totalPage
        return nil
      }

      if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "f" {
        isSearching = true
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
  
  // MARK: - 隐藏事件，取消按键监听
  private func onDisappear(){
    if let monitor = eventMonitor {
      NSEvent.removeMonitor(monitor)
      eventMonitor = nil
    }
  }

  // MARK: - 空页面
  private func emptyView() -> some View {
    Text(paster.history.isEmpty
      ? String(localized: "No paste history available.")
      : String(localized: "No matching clipboard items."))
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
  
  // MARK: - 内容页面
  private func contentView() -> some View {
    return VStack(spacing: 10) {
      
      ScrollViewReader { proxy in
        
        ScrollView(.horizontal, showsIndicators: false) {
          
          LazyHStack(spacing: 0) {
            
            ForEach(0..<totalPage, id: \.self) { pageIndex in
              HStack(spacing: constant.spacing) {
                // 必须使用模型唯一 ID。PasterModel 的 Equatable 按内容判断相等，
                // 不能把整个对象作为 SwiftUI 行 ID；置顶导致重排时会出现行复用错误。
                ForEach(Array(rows(pageIndex).enumerated()), id: \.element.id) { index, item in
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
        .onChange(of: searchText) {
          proxy.scrollTo(0, anchor: .leading)
        }
      }
      
      // 自定义分页指示器
      PageIndicator(total: totalPage, current: $currentPage)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
  
  var body: some View {
    
    VStack(spacing: 12) {
      HStack(spacing: 8) {
        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
        TextField("Search text or app…", text: $searchText)
          .textFieldStyle(.plain)
          .focused($isSearching)
          .accessibilityLabel(String(localized: "Search text or app…"))
        if !searchText.isEmpty {
          Button {
            searchText = ""
            isSearching = true
          } label: {
            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
          }
          .buttonStyle(.plain)
          .help(String(localized: "Clear search"))
        }
        Text(verbatim: "\(filteredHistory.count)")
          .monospacedDigit()
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .modifier(PasterToolbarSurface())

      if filteredHistory.isEmpty {
        emptyView()
      } else {
        contentView()
      }
    }
    .padding(.horizontal, constant.padding)
    .padding(.vertical, 16)
    .onChange(of: searchText) {
      currentPage = 0
      refreshResults(paster.history)
    }
    .onReceive(paster.$history) { refreshResults($0) }
    .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
      if notification.object is PasterHistoryWindow { onDisappear() }
    }
    .onAppear(perform: onAppear)
    .onDisappear(perform: onDisappear)
  }
}

private struct PasterToolbarSurface: ViewModifier {
  @ViewBuilder
  func body(content: Content) -> some View {
    if #available(macOS 26.0, *) {
      content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
    } else {
      content.background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
    }
  }
}

