//
//  Runner.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/8/25.
//

import SwiftUI

class Runner {
  
  public static let shared = Runner()
  
  public func mound(item: NSStatusItem){
    if let button = item.button {
      if let image = NSImage(named: "m-finder") {
        image.size = NSSize(width: 28, height: 28)
        button.image = image
        button.target = self
      }
    }
    // 初始化菜单
    item.menu = AppMenu.shared.getMenus()
  }
  
}
