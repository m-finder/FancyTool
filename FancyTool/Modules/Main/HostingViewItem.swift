//
//  MainStatusItem.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/11.
//

import SwiftUI

class HostingViewItem: ObservableObject{
  
  private var item: NSStatusItem
  
  init(){
    item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    print("Hosting View Item NSStatusItem init")
  }
  
  convenience init(view: some View){
    
    self.init()
    
    if let button = item.button {
      
      // 创建视图
      let hostingView = NSHostingView(
        rootView: view.fixedSize().aspectRatio(
          contentMode: .fit
        )
      )
      
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
      button.target = self
    }
    
    print("Hosting View Item NSHostingView init")
    
  }
  
  convenience init(view: some View, menu: NSMenu){
    self.init(view: view)
    item.menu = menu
    
    print("Hosting View Item NSMenu init")
  }
  
}
