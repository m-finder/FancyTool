//
//  Hidder.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import SwiftUI

@MainActor
extension NSStatusItem {
  var isExpanded: Bool {
    get { length == Hidder.shared.length }
    set { length = newValue ? Hidder.shared.length : CGFloat(Hidder.shared.size) }
  }
}

@MainActor
class Hidder {
  
  public static let shared = Hidder()
  
  public var length: CGFloat = 10000
  private var items: [NSStatusItem] = []
  
  public var size: Int {
    AppState.shared.hidderSize
  }
  
  private var leftItem: NSStatusItem? {
    items.min(by: {
      ($0.button?.window?.frame.minX ?? .greatestFiniteMagnitude) <
        ($1.button?.window?.frame.minX ?? .greatestFiniteMagnitude)
    })
  }
  
  // MARK: - 挂载
  public func mount(){
    
    self.unmount()
    
    for _ in 0..<2 {
      
      let item: NSStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
      
      if let button = item.button, let image = NSImage(named: NSImage.Name("Circle")) {
        image.size = NSSize(width: size, height: size)
        image.isTemplate = true
        
        button.image = image
        button.target = AppMenuActions.shared
        button.action = #selector(AppMenuActions.toggle(_:))
      }
      
      self.items.append(item)
    }
    
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
  
  // MARK: - 显示｜隐藏控制
  public func toggle() {
    self.leftItem?.isExpanded.toggle()
  }
  
  // MARK: - 刷新 hidder 图标的尺寸
  public func refresh() {
    let newSize = CGFloat(size)
    
    for item in items {
      if let button = item.button, let image = NSImage(named: NSImage.Name("Circle")) {
        image.size = NSSize(width: newSize, height: newSize)
        image.isTemplate = true
        button.image = image
      }
    }
  }
  
}
