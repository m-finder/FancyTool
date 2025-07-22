//
//  Paster.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/19.
//
import AppKit
import Foundation
import KeyboardShortcuts

class Paster: ObservableObject{
  
  
  private var timer: Timer?
  public var changeCount: Int
  public static let shared = Paster()
  
  @Published var state = AppState.shared
  @Published public private(set) var history: [String] = []
  public var window: PasterHistoryWindow?
  private let pasteboard = NSPasteboard.general
  private var targetApp: NSRunningApplication?
  
  init(){
    changeCount = pasteboard.changeCount
    print("Paster init")
  }
  
  public func mount(){
    timer = Timer.scheduledTimer(
      timeInterval: 0.5,
      target: AppMenuActions.shared,
      selector: #selector(AppMenuActions.clipboard(_:)),
      userInfo: nil,
      repeats: true
    )
    
    // 监听快捷键
    KeyboardShortcuts.onKeyUp(for: .paster) { [self] in
      DispatchQueue.main.async {
        self.targetApp = NSWorkspace.shared.frontmostApplication
        if self.window == nil {
          self.show()
        } else {
          self.hide()
        }
      }
    }
    
    print("Start Paster listen")
  }
  
  public func unmount(){
    timer?.invalidate()
    timer = nil
    
    KeyboardShortcuts.disable(.paster)
    print("Stop Paster listen")
  }
  
  public func show(){
    self.window = PasterHistoryWindow(contentView: PasterView())
    self.window?.isReleasedWhenClosed = false
    NSApp.activate(ignoringOtherApps: true)
    self.window?.orderFrontRegardless()
  }
  
  public func hide(){
    self.window?.close()
    self.window = nil
  }
  
  public func append(_ record: String){
    if history.contains(record) {
      history.removeAll(where: { $0 == record})
    }
    
    history.insert(record, at: 0)
    
    if history.count > state.historyCount {
      history.removeLast()
    }
  }
  
  public func copyToClipboard(_ text: String) -> Bool {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    
    let success = pasteboard.setString(text, forType: .string)
    // 验证剪贴板内容是否设置成功
    if success, let copiedText = pasteboard.string(forType: .string), copiedText == text {
      return true
    } else {
      return false
    }
  }
  
  public func simulatePaste(to application: NSRunningApplication? = nil) {

    let targetApp = self.targetApp
    
    guard hasAccessibilityPermission() else {
      print("缺少辅助功能权限")
      showAccessibilityPermissionAlert()
      return
    }
    
    guard let source = CGEventSource(stateID: .hidSystemState) else {
      print("无法创建事件源")
      return
    }
    
    targetApp?.activate(options: [.activateAllWindows])
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      // 模拟完整的 Command+V 粘贴操作
      let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
      let vKeyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
      let vKeyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
      let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)
      
      cmdDown?.flags = .maskCommand
      vKeyDown?.flags = .maskCommand
      
      // 设置事件目标进程
      if let pid = targetApp?.processIdentifier {
        cmdDown?.postToPid(pid)
        usleep(5000)
        vKeyDown?.postToPid(pid)
        vKeyUp?.postToPid(pid)
        cmdUp?.postToPid(pid)
      }
    }
    
  }
  
  
  // 检查是否有辅助功能权限
  private func hasAccessibilityPermission() -> Bool {
    let accessEnabled = AXIsProcessTrustedWithOptions([
      kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
    ] as CFDictionary)
    return accessEnabled
  }
  
  // 显示权限提示
  private func showAccessibilityPermissionAlert() {
    let alert = NSAlert()
    alert.messageText = "需要辅助功能权限"
    alert.informativeText = "请在系统设置 > 安全性与隐私 > 隐私 > 辅助功能中，启用本应用的权限，以允许粘贴操作。"
    alert.addButton(withTitle: "确定")
    alert.runModal()
  }
}
