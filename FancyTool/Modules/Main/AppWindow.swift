//
//  AppWindow.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//
import SwiftUI

@MainActor
class AppWindow {
  
  private var window: NSWindow!
  private let hidesToolbar: Bool
  
  init(
    title: String,
    size: NSSize = NSSize(width: 440, height: 400),
    minimumSize: NSSize? = nil,
    isResizable: Bool = false,
    hidesToolbar: Bool = false,
    contentView: some View
  ) {

    self.hidesToolbar = hidesToolbar
    
    if window == nil {
      
      let rootView = contentView.frame(
        maxWidth: .infinity
      )
      
      var styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable]
      if isResizable {
        styleMask.insert(.resizable)
      }

      // 配置窗口属性
      window = NSWindow(
        contentRect: NSRect(origin: .zero, size: size),
        styleMask: styleMask,
        backing: .buffered,
        defer: false
      )
      window?.center()
      window?.title = title
      window?.isReleasedWhenClosed = false
      window?.contentView = NSHostingView(rootView: rootView)
      window?.minSize = minimumSize ?? size
    }
  }
  
  // MARK: - 显示窗口
  public func show(){
    if hidesToolbar {
      window?.toolbar = nil
    }

    NSApp.activate(ignoringOtherApps: true)
    window?.makeKeyAndOrderFront(nil)

    if hidesToolbar {
      DispatchQueue.main.async { [weak self] in
        self?.window?.toolbar = nil
      }
    }
  }
  
}
