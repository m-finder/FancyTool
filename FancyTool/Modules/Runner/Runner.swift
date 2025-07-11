//
//  Runner.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import SwiftUI
import SwiftData

class Runner: NSObject, NSWindowDelegate {
  
  private var size: CGFloat = 20
  private var sharedModelContainer = RunnerHandler.shared.container
  private var item: NSStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  
  @MainActor func mount(menu: NSMenu){
    
    if let button = item.button {
      
      // 创建视图
      let runnerView = RunnerView(height: size)
        .fixedSize()
        .frame(
          minWidth: 40,
          maxWidth: .infinity
        ).modelContainer(sharedModelContainer)
      let hostingView = NSHostingView(rootView: runnerView)
      button.addSubview(hostingView)
      
      // 将宿主视图四边锚定到按钮边界，也就是将视图展开
      hostingView.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        hostingView.topAnchor.constraint(equalTo: item.button!.topAnchor),
        hostingView.bottomAnchor.constraint(equalTo: item.button!.bottomAnchor),
        hostingView.leadingAnchor.constraint(equalTo: item.button!.leadingAnchor),
        hostingView.trailingAnchor.constraint(equalTo: item.button!.trailingAnchor)
      ])
      
      // 设置按钮
      button.title = ""
      button.target = self
    }

    // 绑定菜单
    item.menu = menu
  }
}
