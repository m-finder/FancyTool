//
//  MenuActions.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//
import AppKit

@MainActor
class AppMenuActions: NSObject {
  
  static let shared = AppMenuActions()
  
  private var settingsWindow: AppWindow?
  private var aboutWindow: AppWindow?
  
  // MARK: - 退出
  @IBAction func quit(_ sender: Any){
    NSApplication.shared.terminate(nil)
  }
  
  // MARK: - 打开设置窗口
  @IBAction func setting(_ sender: Any){
    if settingsWindow == nil{
      settingsWindow = AppWindow(
        title: String(localized: "Setting"),
        contentView: SettingsView()
      )
    }
    
    settingsWindow?.show()
  }
  
  // MARK: - 打开关于窗口
  @IBAction func about(_ sender: Any){
    if aboutWindow == nil {
      aboutWindow = AppWindow(
        title: String(localized: "About"),
        contentView: AboutView()
      )
    }
    
    aboutWindow?.show()
  }
  
  // MARK: - 停启用菜单折叠
  @IBAction func hidder(_ sender: NSStatusBarButton){
    AppState.shared.showHidder.toggle()
    sender.state = AppState.shared.showHidder ? .on : .off
    
    if(AppState.shared.showHidder){
      Hidder.shared.mount()
    }else{
      Hidder.shared.unmount()
    }
  }
  
  // MARK: - 菜单折叠点击事件
  @IBAction func toggle(_ sender: NSStatusBarButton){
    Hidder.shared.toggle()
  }
  
  // MARK: - 停启用炫彩文字
  @IBAction func texter(_ sender: NSStatusBarButton){
    AppState.shared.showTexter.toggle()
    sender.state = AppState.shared.showTexter ? .on : .off
    
    if(AppState.shared.showTexter){
      Texter.shared.mount()
    }else{
      Texter.shared.unmount()
    }
  }
  
  // MARK: - 炫彩文字点击事件，弹出操作窗口
  @IBAction func textPopover(_ sender: NSStatusBarButton){
    if Texter.shared.popover.isShown{
      if let window = Texter.shared.popover.contentViewController?.view.window {
        window.orderFrontRegardless()
      }

      Texter.shared.popover.performClose(sender)
      return
    }

    Texter.shared.show(sender)
  }
  
  // MARK: - 停启用剪贴板
  @IBAction func paster(_ sender: NSStatusBarButton){
    AppState.shared.showPaster.toggle()
    sender.state = AppState.shared.showPaster ? .on : .off
    
    if(AppState.shared.showPaster){
      Paster.shared.mount()
    }else{
      Paster.shared.unmount()
    }
  }
  
  // MARK: - 剪贴板监听事件
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
    else if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
            let image = images.first {
      if let imageData = image.tiffRepresentation,
         let bitmapImage = NSBitmapImageRep(data: imageData),
         let data = bitmapImage.representation(using: .png, properties: [:]) {
        Paster.shared.append(PasterModel(image: data, icon: appIcon))
      }
    }
  }
  
  // MARK: - 停启用屏幕圆角
  @IBAction func rounder(_ sender: NSStatusBarButton){
    AppState.shared.showRounder.toggle()
    sender.state = AppState.shared.showRounder ? .on : .off
    
    if(AppState.shared.showRounder){
      Rounder.shared.mount()
    }else{
      Rounder.shared.unmount()
    }
  }
  
  // MARK: - 停启用监控
  @IBAction func monitor(_ sender: NSStatusBarButton){
    AppState.shared.showMonitor.toggle()
    sender.state = AppState.shared.showMonitor ? .on : .off
    
    if(AppState.shared.showMonitor){
      if(
        !AppState.shared.showCpu &&
        !AppState.shared.showNetWork &&
        !AppState.shared.showStorage &&
        !AppState.shared.showBattery &&
        !AppState.shared.showMemory
      ){
        AppState.shared.showCpu = true
      }
      Monitor.shared.mount()
    }else{
      Monitor.shared.unmount()
    }
  }
  
  @IBAction func monitorPopover(_ sender: NSStatusBarButton){
    if Monitor.shared.popover.isShown{
      if let window = Monitor.shared.popover.contentViewController?.view.window {
        window.orderFrontRegardless()
      }

      Monitor.shared.popover.performClose(sender)
      return
    }

    Monitor.shared.show(sender)
  }
  
  // MARK: - 空响应
  @IBAction func nullAction(_ sender: NSStatusBarButton){

  }

}
