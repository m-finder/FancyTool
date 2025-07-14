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
    print("Hidder clicked")
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
    print("Hidder toggle")
  }
  
}
