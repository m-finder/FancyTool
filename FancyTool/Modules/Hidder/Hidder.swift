//
//  Hidder.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import SwiftUI

class Hidder {

  static let shared = Hidder()
  private var showLength: CGFloat =  6
  private var hiddenLength: CGFloat = 10000
  private var items: [NSStatusItem] = []
  
  public func mount(){
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
      self?.setup()
      self?.setup()
    }
  }
  
  public func unmount(){
    for item in items {
      if let button = item.button {
        button.image = nil
      }
      NSStatusBar.system.removeStatusItem(item)
    }
    items.removeAll()
  }
  
  private func setup(){
    let statusItem: NSStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    if let button = statusItem.button {
      let image = NSImage(named: NSImage.Name("Circle"))
    
      image?.size = NSSize(width: showLength, height: showLength)
      image?.isTemplate = true
      button.image = image
      let target = AppMenuActions.shared
      button.target = target
      button.action = #selector(AppMenuActions.toggle(_:))
      button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }
    items.append(statusItem)
  }
  
  public func toggle() {
    let leftItem = items.min(by: { ($0.button?.window?.frame.origin.x)! < ($1.button?.window?.frame.origin.x)! })
    if leftItem?.length == hiddenLength {
      leftItem?.length = showLength
    }else{
      leftItem?.length = hiddenLength
    }
  }
}
