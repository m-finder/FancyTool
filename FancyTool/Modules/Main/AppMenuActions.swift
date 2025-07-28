//
//  MenuActions.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//
import AppKit

class AppMenuActions: NSObject {
  
  static let shared = AppMenuActions()
  
  @IBAction func quit(_ sender: Any){
    NSApplication.shared.terminate(nil)
  }
  
  @IBAction func setting(_ sender: Any){
    _ = AppWindow(
      title: String(localized: "Setting"),
      contentView: SettingsView()
    )
  }
  
  @IBAction func about(_ sender: Any){
    _ = AppWindow(
      title: String(localized: "About"),
      contentView: AboutView()
    )
  }
  
  @IBAction func hidder(_ sender: NSStatusBarButton){
    AppState.shared.showHidder.toggle()
    sender.state = AppState.shared.showHidder ? .on : .off
    if(AppState.shared.showHidder){
      Hidder.shared.mount()
    }else{
      Hidder.shared.unmount()
    }
  }
  
  @IBAction func toggle(_ sender: NSStatusBarButton){
    Hidder.shared.toggle()
  }
  
  
  @IBAction func texter(_ sender: NSStatusBarButton){
    AppState.shared.showTexter.toggle()
    sender.state = AppState.shared.showTexter ? .on : .off
    if(AppState.shared.showTexter){
      Texter.shared.mount()
    }else{
      Texter.shared.unmount()
    }
  }
  
  @IBAction func popover(_ sender: NSStatusBarButton){
    if Texter.shared.popover.isShown{
      if let window = Texter.shared.popover.contentViewController?.view.window {
        window.orderFrontRegardless()
      }
      Texter.shared.popover.performClose(sender)
      return
    }
    Texter.shared.show(sender)
  }
  
  @IBAction func paster(_ sender: NSStatusBarButton){
    AppState.shared.showPaster.toggle()
    sender.state = AppState.shared.showPaster ? .on : .off
    if(AppState.shared.showPaster){
      Paster.shared.mount()
      print("Paster mount")
    }else{
      Paster.shared.unmount()
      print("Paster unmount")
    }
  }
  
  @IBAction func clipboard(_: NSPasteboard) {
    let pasteboard = NSPasteboard.general
    guard pasteboard.changeCount != Paster.shared.changeCount else { return }
    Paster.shared.changeCount = pasteboard.changeCount
    
    let sourceApp = NSWorkspace.shared.frontmostApplication
    let appIcon = sourceApp?.bundleURL?.path ?? "Unknown"

    if let copiedText = pasteboard.string(forType: .string) {
      let trimmedText = copiedText.trimmingCharacters(in: .whitespacesAndNewlines)
      
      if !trimmedText.isEmpty {
        Paster.shared.append(PasterModel(content: copiedText, icon: appIcon))
      }
    }
  }
}
