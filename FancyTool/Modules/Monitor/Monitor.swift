//
//  Hidder.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import SwiftUI

@MainActor
class Monitor {
  
  public static let shared = Monitor()
  private var items: [NSStatusItem] = []
  
 
  // MARK: - 挂载
  public func mount(){
    
    self.unmount()
    
    let item: NSStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    if let button = item.button {
      button.target = AppMenuActions.shared
      button.action = #selector(AppMenuActions.toggle(_:))
    }
    
    self.items.append(item)
    
  }
  
  // MARK: - 取消挂载
  public func unmount(){
    
    for item in items {
      if let button = item.button {
        button.image = nil
      }
      NSStatusBar.system.removeStatusItem(item)
    }
    items.removeAll()
    
  }

  // MARK: - 刷新 hidder 图标的尺寸
  public func refresh() {
    
  }
  
}
