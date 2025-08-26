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
  
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    Settings{
      EmptyView()
    }
  }
}
