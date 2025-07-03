//
//  FancyToolApp.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import SwiftUI
import SwiftData

@main
struct FancyToolApp: App {
  
  // 代理适配器，托管应用的生命周期
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  
  var body: some Scene {
    Settings{
      EmptyView()
    }
  }
}
