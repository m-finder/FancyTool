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
  @AppStorage("fontSize") var fontSize: Int = 14
  @AppStorage("text") var text: String = String(localized: "Keep happy.")
  
  
  // Paster
  @AppStorage("showPaster") var showPaster: Bool = false
  @AppStorage("historyCount") var historyCount: Int = 20
  // 开启后选中历史项会自动模拟 Command+V 粘贴到目标 app，需要辅助功能权限。
  // 关闭时只写入剪贴板并切回目标 app，用户自行按一次 Command+V。
  @AppStorage("autoPaste") var autoPaste: Bool = false
  
  // Rounder
  @AppStorage("showRounder") var showRounder: Bool = false
  @AppStorage("radius") var radius = 10
  
  // Monitor
  @AppStorage("showMonitor") var showMonitor: Bool = false
  @AppStorage("showCpu") var showCpu: Bool = false
  @AppStorage("showNetWork") var showNetWork: Bool = false
  @AppStorage("showStorage") var showStorage: Bool = false
  @AppStorage("showMemory") var showMemory: Bool = false
  @AppStorage("showBattery") var showBattery: Bool = false

  // Shotter
  @AppStorage("showShotter") var showShotter: Bool = false

  private init() {
    let defaults = UserDefaults.standard
    if defaults.object(forKey: "showShotter") == nil,
       defaults.object(forKey: "showScreenshot") != nil {
      defaults.set(defaults.bool(forKey: "showScreenshot"), forKey: "showShotter")
    }
  }
  
  // 最新的系统快照
  @Published var bundle: SystemInfoBundle?
  
  private var observer = SystemInfoObserver.shared
  
  // 开始系统监控
  public func start() {
    observer.startMonitoring(monitorInterval: 5)
    Task {
      for await b in observer.systemInfoStream() {
        await MainActor.run { bundle = b }
      }
    }
  }
  
  // 停止系统监控
  public func stop() { observer.stopMonitoring() }
}
