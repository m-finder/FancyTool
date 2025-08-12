//
//  Hidder.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import SwiftUI

class Hidder {

  static let shared = Hidder()
  private var hiddenLength: CGFloat = 10000
  private var items: [NSStatusItem] = []
  @Published var state = AppState.shared
  
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
    
      image?.size = NSSize(width: state.hidderSize, height: state.hidderSize)
      image?.isTemplate = true
      button.image = image
      button.target = AppMenuActions.shared
      button.action = #selector(AppMenuActions.toggle(_:))
    }
    items.append(statusItem)
  }
  
  public func toggle() {
    let leftItem = items.min(by: { ($0.button?.window?.frame.origin.x)! < ($1.button?.window?.frame.origin.x)! })
    if leftItem?.length == hiddenLength {
      leftItem?.length = CGFloat(state.hidderSize)
    }else{
      leftItem?.length = hiddenLength
    }
  }
  
  public func refresh() {
    let newSize = CGFloat(state.hidderSize)
    for item in items {
      guard let button = item.button else { continue }
     
      let image = NSImage(named: NSImage.Name("Circle"))
      image?.size = NSSize(width: newSize, height: newSize)
      image?.isTemplate = true
      button.image = image
      
      // 更新长度
      if item.length != hiddenLength {
        item.length = newSize
      }
    }
  }
}
