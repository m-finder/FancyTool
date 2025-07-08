//
//  Hidder.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import SwiftUI

class Hidder {
  
  var state = AppState.shared
  var hidderClickHandler: (() -> Void)?
  private var showLength: CGFloat =  6
  private let hiddenLength: CGFloat = 10000
  private var items: [NSStatusItem] = []
  
  @MainActor public func update() {
    if state.showHidder {
      mount()
    } else {
      unmount()
    }
  }
  
  // 挂载 2 个图标
  @MainActor public func mount(){
    setup()
    setup()
  }
  
  @MainActor private func setup(){
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    if let button = statusItem.button {
      let image = NSImage(named: NSImage.Name("Circle"))
      image?.size = NSSize(width: showLength, height: showLength)
      image?.isTemplate = true
      button.image = image
      button.target = self
      button.action = #selector(handleHidderClick)
      button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }
    items.append(statusItem)
  }
  
  @MainActor public func unmount() {
    for item in items {
      if let button = item.button {
        button.image = nil
      }
      NSStatusBar.system.removeStatusItem(item)
    }
    items.removeAll()
  }
  
  public func hidderCollapseMenuBar() {
    let leftItem = items.min(by: { ($0.button?.window?.frame.origin.x)! < ($1.button?.window?.frame.origin.x)! })
    if leftItem?.length == hiddenLength {
      leftItem?.length = showLength
    }else{
      leftItem?.length = hiddenLength
    }
  }
  
  // 调用闭包
  @objc private func handleHidderClick() {
    hidderClickHandler?()
  }
}
