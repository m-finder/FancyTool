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
  private var hostingView: HostingViewItem!
  private var popoverView = TexterPopoverView()
  private var controller: NSViewController!
  
  func mount(){
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
      self?.hostingView = HostingViewItem(
        view: TexterView()
          .frame(minWidth: 40, maxWidth: .infinity)
          .padding(.horizontal, 5)
          .fixedSize(),
        target: AppMenuActions.shared,
        action: #selector(AppMenuActions.popover(_:))
      )
    }
  }
  
  
  func unmount(){
    popover.close()
    hostingView = nil
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
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
      self.popover.show(
        relativeTo: sender.bounds,
        of: sender,
        preferredEdge: .minY
      )
    }
  }
}
