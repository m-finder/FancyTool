//
//  Paster.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/19.
//
import AppKit
import SwiftUI
import Foundation
import KeyboardShortcuts

class Paster: ObservableObject{
  
  private var timer: Timer?
  public var changeCount: Int
  public static let shared = Paster()
  
  @Published var state = AppState.shared
  @Published public private(set) var history: [PasterModel] = []
  
  public var window: PasterHistoryWindow?
  private let pasteboard = NSPasteboard.general
  private var targetApp: NSRunningApplication?
  
  init(){
    changeCount = pasteboard.changeCount
  }
  
  public func mount(){
    unmount()
    
    timer = Timer.scheduledTimer(
      timeInterval: 0.8,
      target: AppMenuActions.shared,
      selector: #selector(AppMenuActions.clipboard(_:)),
      userInfo: nil,
      repeats: true
    )
    
    // 监听快捷键
    KeyboardShortcuts.onKeyUp(for: .paster) { [weak self] in
      DispatchQueue.main.async {
        self?.targetApp = NSWorkspace.shared.frontmostApplication
        if self?.window == nil || self?.window?.isVisible == false{
          self?.show()
        } else {
          self?.hide()
        }
      }
    }
  }
  
  public func unmount(){
    timer?.invalidate()
    timer = nil
    
    KeyboardShortcuts.disable(.paster)
  }
  
  public func show(){
    DispatchQueue.main.async {
      if self.window == nil {
        self.window = PasterHistoryWindow(contentView: PasterView())
        self.window?.isReleasedWhenClosed = false
      }
      
      NSApp.activate(ignoringOtherApps: true)
      self.window?.makeKeyAndOrderFront(nil)
      self.window?.orderFrontRegardless()
    }
  }
  
  public func hide(){
    DispatchQueue.main.async {
      self.window?.close()
      self.window = nil
    }
  }
  
  public func append(_ record: PasterModel){
    if history.contains(record) {
      history.removeAll(where: { $0 == record})
    }
    
    history.insert(record, at: 0)
    
    if history.count > state.historyCount {
      history.removeLast()
    }
  }
  
  public func tap(_ item: PasterModel) {
    let success = self.copyToClipboard(item)
    
    guard success, let targetApp = NSWorkspace.shared.frontmostApplication else { return }
    
    self.hide()
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      self.simulatePaste(to: targetApp)
    }
  }
  
  public func copyToClipboard(_ item: PasterModel) -> Bool {
    pasteboard.clearContents()
    
    // 文本复制
    if let textContent = item.content, !textContent.isEmpty {
      let success = pasteboard.setString(textContent, forType: .string)
      if success, let copiedText = pasteboard.string(forType: .string), copiedText == item.content {
        return true
      } else {
        return false
      }
    }
    
    // 图片复制
    else if let imageData = item.image, let image = NSImage(data: imageData) {
      let success = pasteboard.writeObjects([image])
      if success, let pastedImages = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
         !pastedImages.isEmpty {
        return true
      }
      return false
    }
    
    return false
  }
  
  public func simulatePaste(to application: NSRunningApplication? = nil) {
    let targetApp = self.targetApp
    guard hasAccessibilityPermission() else {
      showAccessibilityPermissionAlert()
      return
    }
    
    guard let source = CGEventSource(stateID: .hidSystemState) else {
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
        usleep(1000)
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
      alert.messageText = NSLocalizedString("Need Accessibility Permissions", comment: "Alert title for accessibility permission request")
      alert.informativeText = NSLocalizedString("Please enable permissions for this app in System Settings > Security & Privacy > Privacy > Accessibility to allow paste operations.", comment: "Detailed explanation for accessibility permission request")
      alert.addButton(withTitle: NSLocalizedString("OK", comment: "Confirm button text"))
      alert.runModal()
  }
}
