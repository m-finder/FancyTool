//
//  Texter.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import SwiftUI
import AppKit

class Texter {
  
  static let shared = Texter()
  public let popover = NSPopover()
  private var popoverView = TexterPopoverView()
  private var controller: NSViewController!
  private var item: NSStatusItem?
  
  func mount(){
    
    self.item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    guard let button = self.item?.button else { return }
 
    // 设置图标视图&&绑定到按钮
    let _ = HostingView(
      view: TexterView().frame(minWidth: 40, maxWidth: .infinity).padding(.horizontal, 5),
      button: button,
      target: AppMenuActions.shared,
      action: #selector(AppMenuActions.popover(_:))
    )
  }
  
  
  func unmount(){
    popover.close()
    item = nil
  }
  
  func show(_ sender: NSStatusBarButton){
    if(controller == nil){
      controller = NSHostingController(
        rootView: popoverView.frame(
          maxWidth: .infinity,
          maxHeight: .infinity
        ).padding()
      )
    }
    popover.contentSize = .init(width: 350, height: 320)
    popover.contentViewController = controller
    popover.behavior = .transient
    popover.animates = true

    self.popover.show(
      relativeTo: sender.bounds,
      of: sender,
      preferredEdge: .minY
    )
  }
}
