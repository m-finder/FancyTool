//
//  Texter.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import SwiftUI

class Texter {
  
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    @AppStorage("showTexter") var showTexter = false
    
    func setup() {
        guard showTexter else { return }
        // 初始化代码...
    }
    
    func toggle() {
        showTexter.toggle()
        showTexter ? setup() : remove()
    }
    
    private func remove() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }
}
