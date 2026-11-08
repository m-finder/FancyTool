//
//  AppState.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
  case light
  case dark
  case automatic

  var id: Self { self }

  var title: String {
    switch self {
    case .light: String(localized: "Light")
    case .dark: String(localized: "Dark")
    case .automatic: String(localized: "Automatic")
    }
  }

  var nsAppearance: NSAppearance? {
    switch self {
    case .light: NSAppearance(named: .aqua)
    case .dark: NSAppearance(named: .darkAqua)
    case .automatic: nil
    }
  }
}

@MainActor
final class AppState: ObservableObject {
  
  static let shared = AppState()
  
  // 主程序配置
  @AppStorage("startUp") var startUp: Bool = false
  @AppStorage("appAppearance") var appAppearance: AppAppearance = .automatic {
    didSet { applyAppearance() }
  }

  func applyAppearance() {
    NSApp.appearance = appAppearance.nsAppearance
  }
  
  // Runner
  @AppStorage("runnerId") var runnerId: String = ""
  @AppStorage("runnerCompanion") var runnerCompanion: Bool = false
  
  // Hidder
  @AppStorage("showHidder") var showHidder: Bool = false
  @AppStorage("hidderSize") var hidderSize = 6
  
  
  // Texter
  @AppStorage("showTexter") var showTexter: Bool = false
  @AppStorage("showShimmer") var showShimmer: Bool = true
  @AppStorage("rainbowShimmer") var rainbowShimmer: Bool = false
  @AppStorage("colorIndex") var colorIndex: Int = 0
  @AppStorage("fontSize") var fontSize: Int = 14
  @AppStorage("texterFontFamily") var texterFontFamily: String = ""
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
  @AppStorage("monitorColoredIcons") var monitorColoredIcons: Bool = true

  // Shotter
  @AppStorage("showShotter") var showShotter: Bool = false

  private init() {
    let defaults = UserDefaults.standard
    if defaults.object(forKey: "showShotter") == nil,
       defaults.object(forKey: "showScreenshot") != nil {
      defaults.set(defaults.bool(forKey: "showScreenshot"), forKey: "showShotter")
    }
  }
  
}
