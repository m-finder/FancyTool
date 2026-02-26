//
//  Hidder.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import SwiftUI
import SystemInfoKit

@MainActor
class Monitor {
  
  public static let shared = Monitor()
  private var item: NSStatusItem?
  public let popover = NSPopover()
  private var popoverView = MonitorPopoverView()
  private var controller: NSViewController!
  private var defaultIconName = "m-finder"
  
  @ObservedObject var state = AppState.shared
  
  // MARK: - 挂载
  public func mount(){
    
    if item == nil {
      item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    }
    
    guard let button = item?.button else { return }
    
    // 强制选中
    button.state = .on

    button.subviews.forEach { $0.removeFromSuperview() }
    button.image = nil
    button.title = ""
    
    
    let hasActiveMonitor = state.showCpu || state.showNetWork || state.showStorage || state.showMemory || state.showBattery
    
    if hasActiveMonitor {
      let _ = HostingView(
        view: MonitorView().frame(height: 22).frame(minWidth: 40, maxWidth: .infinity).padding(.horizontal, 4),
        button: button,
        target: AppMenuActions.shared,
        action: #selector(AppMenuActions.monitorPopover(_:))
      )
    }else{
      button.image = NSImage(named: self.defaultIconName)?.resized(to: 28)
      button.target = AppMenuActions.shared
      button.action = #selector(AppMenuActions.monitorPopover(_:))
    }
    
  }
  
  // MARK: - 取消挂载
  public func unmount(){
    if let existingItem = self.item {
      // 移除状态栏项
      NSStatusBar.system.removeStatusItem(existingItem)
      // 清空按钮内容
      existingItem.button?.image = nil
      existingItem.button?.title = ""
    }
    // 清空引用，避免野指针
    self.item = nil
  }
  
  // MARK: - 弹窗
  public func show(_ sender: NSStatusBarButton){
    if(controller == nil){
      controller = NSHostingController(
        rootView: popoverView.frame(
          maxWidth: .infinity,
          maxHeight: .infinity
        ).padding()
      )
    }
    popover.contentSize = .init(width: 220, height: 430)
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
// MARK: - NSImage 扩展
private extension NSImage {
  func resized(to size: CGFloat) -> NSImage {
    let newImage = NSImage(size: NSSize(width: size, height: size))
    newImage.lockFocus()
    draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    newImage.unlockFocus()
    return newImage
  }
}
