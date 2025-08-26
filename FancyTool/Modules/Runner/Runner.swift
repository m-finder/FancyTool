//
//  Runner.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/8/25.
//

import Foundation
import SwiftUI

class Runner {
  
  public static let shared = Runner()
  
  public func mound(item: NSStatusItem){
    
    // 获取图标的按钮
    guard let button = item.button else { return }
 
    // 设置图标视图&&绑定到按钮
    let _ = HostingView(
      view: RunnerMainView(height: 22).frame(minWidth: 40, maxWidth: .infinity),
      button: button
    )
    
    // 设置按钮目标
    button.target = self
    
    // 初始化菜单
    let appMenu = AppMenu(
      actions: AppMenuActions.shared,
      items: MenuItem.menus()
    )
    item.menu = appMenu.getMenus()
  }
  
}
