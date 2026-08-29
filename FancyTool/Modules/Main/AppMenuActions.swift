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
        size: NSSize(width: 640, height: 400),
        minimumSize: NSSize(width: 600, height: 380),
        isResizable: true,
        hidesToolbar: true,
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
    AppMenu.shared.refreshFeatureStates()
  }
  
  // MARK: - 菜单折叠点击事件
  @IBAction func toggle(_ sender: NSStatusBarButton){
    Hidder.shared.toggle()
  }
  
  // MARK: - 停启用炫彩签名
  @IBAction func texter(_ sender: NSStatusBarButton){
    AppState.shared.showTexter.toggle()
    sender.state = AppState.shared.showTexter ? .on : .off
    
    if(AppState.shared.showTexter){
      Texter.shared.mount()
    }else{
      Texter.shared.unmount()
    }
    AppMenu.shared.refreshFeatureStates()
  }
  
  // MARK: - 炫彩签名点击事件，弹出操作窗口
  @IBAction func textPopover(_ sender: NSStatusBarButton){
    if Texter.shared.popover.isShown {
      // The status item is also the popover's anchor. Bringing its window to
      // front before closing can cause a visible jump after repeated clicks.
      // Close synchronously so a new show request cannot race the close
      // animation.
      Texter.shared.popover.close()
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
    AppMenu.shared.refreshFeatureStates()
  }
  
  // MARK: - 剪贴板监听事件
  @IBAction func clipboard(_: NSPasteboard) {
    Paster.shared.pollClipboard()
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
    AppMenu.shared.refreshFeatureStates()
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
    AppMenu.shared.refreshFeatureStates()
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

  // MARK: - 停启用 Shotter
  @IBAction func shotter(_ sender: NSStatusBarButton){
    AppState.shared.showShotter.toggle()
    sender.state = AppState.shared.showShotter ? .on : .off

    if AppState.shared.showShotter {
      Shotter.shared.mount()
    } else {
      Shotter.shared.unmount()
    }
    AppMenu.shared.refreshFeatureStates()
  }

  // MARK: - 空响应
  @IBAction func nullAction(_ sender: NSStatusBarButton){

  }

}
