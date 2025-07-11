//
//  MenuActions.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//
import AppKit

class AppMenuActions: NSObject {
  
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
  
}
