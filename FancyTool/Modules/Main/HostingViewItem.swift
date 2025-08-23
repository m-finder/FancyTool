//
//  MainStatusItem.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import SwiftUI

class HostingViewItem: ObservableObject{
  
  private var item: NSStatusItem?
  
  init(){
    DispatchQueue.main.async { [weak self] in
      self?.item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    }
  }
  
  convenience init(view: some View) {
    
    self.init()
    
    DispatchQueue.main.async { [weak self] in
      guard let self = self, let item = self.item, let button = item.button else { return }
      
      
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
        hostingView.topAnchor.constraint(equalTo: button.topAnchor),
        hostingView.bottomAnchor.constraint(equalTo: button.bottomAnchor),
        hostingView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
        hostingView.trailingAnchor.constraint(equalTo: button.trailingAnchor)
      ])
      
      // 设置按钮
      button.target = self
      
    }
  }
  
  convenience init(view: some View, target: AnyObject, action: Selector){
    self.init(view: view)
    DispatchQueue.main.async { [weak self] in
      self?.item?.button?.target = target
      self?.item?.button?.action = action
    }
  }
  
  convenience init(view: some View, menu: NSMenu? = nil){
    self.init(view: view)
    
    DispatchQueue.main.async { [weak self] in
      self?.item?.menu = menu
    }
  }
  
}
