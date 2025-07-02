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
  // 数据库管理
  var sharedModelContainer: ModelContainer = {
    let schema = Schema([
      RunnerModel.self
    ])
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    
    do {
      return try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
      fatalError("Could not create ModelContainer: \(error)")
    }
  }()
  
  var body: some Scene {
    Settings{
      EmptyView()
    }.modelContainer(sharedModelContainer)
  }
}
