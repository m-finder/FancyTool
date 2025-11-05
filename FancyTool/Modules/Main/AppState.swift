//
//  AppState.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import SwiftUI
import SystemInfoKit

@MainActor
class AppState : ObservableObject{
  
  static let shared = AppState()
  
  // 主程序配置
  @AppStorage("startUp") var startUp: Bool = false
  
  // Runner
  @AppStorage("runnerSpeed") var runnerSpeed = 0.5
  @AppStorage("speedProportional") var speedProportional = true
  @AppStorage("runnerId") var runnerId: String = ""
  
  // Hidder
  @AppStorage("showHidder") var showHidder: Bool = false
  @AppStorage("hidderSize") var hidderSize = 6
  
  
  // Texter
  @AppStorage("showTexter") var showTexter: Bool = false
  @AppStorage("showShimmer") var showShimmer: Bool = true
  @AppStorage("rainbowShimmer") var rainbowShimmer: Bool = false
  @AppStorage("colorIndex") var colorIndex: Int = 0
  @AppStorage("text") var text: String = String(localized: "Keep happy.")
  
  
  // Paster
  @AppStorage("showPaster") var showPaster: Bool = false
  @AppStorage("historyCount") var historyCount: Int = 20
  
  // Rounder
  @AppStorage("showRounder") var showRounder: Bool = false
  @AppStorage("radius") var radius = 10.0
  
  // Monitor
  @AppStorage("showMonitor") var showMonitor: Bool = false
  @AppStorage("showCpu") var showCpu: Bool = false
  @AppStorage("showNetWork") var showNetWork: Bool = true
  @AppStorage("showStorage") var showStorage: Bool = true
  @AppStorage("showMemory") var showMemory: Bool = true
  @AppStorage("showBattery") var showBattery: Bool = true

  private init() {}
  
  // 最新的系统快照
  @Published var bundle: SystemInfoBundle?
  
  private var observer = SystemInfoObserver.shared
  // 开始系统监控
  public func start() {
    observer.startMonitoring(monitorInterval: 3)
    Task {
      for await b in observer.systemInfoStream() {
        await MainActor.run { bundle = b }
      }
    }
  }
  
  public func stop() { observer.stopMonitoring() }
}
