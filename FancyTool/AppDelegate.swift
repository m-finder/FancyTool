//
//  AppDelegate.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate{
  
  private let runner = Runner()
  
  func applicationDidFinishLaunching(_ aNotification: Notification) {
    runner.handle()
  }
}
