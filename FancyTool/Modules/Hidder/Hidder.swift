//
//  Hidder.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import SwiftUI

class Hidder {
  
  private var showLength: CGFloat =  8
  private let hiddenLength: CGFloat = 10000
  @AppStorage("showHidder") var showHidder: Bool = false
  private var items: [NSStatusItem] = []
  
  deinit {
    unmount()
  }
  
  public func update() {
     if showHidder {
       mount()
     } else {
       unmount()
     }
   }
  
  // 挂载
  public func mount(){
    
//    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
//    if let button = statusItem.button {
//        let image = NSImage(named: NSImage.Name("Circle"))
//        image?.size = NSSize(width: showLength, height: 22)
//        image?.isTemplate = true
//        button.image = image
//        button.target = self
//        button.action = #selector(hidderClick)
//        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
//    }
//    items.append(statusItem)
  }
  
  public func unmount() {
    for item in items {
      NSStatusBar.system.removeStatusItem(item)
    }
    items.removeAll()
  }
  
}
