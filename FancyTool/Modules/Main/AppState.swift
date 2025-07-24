//
//  AppState.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import SwiftUI
class AppState : ObservableObject{
  
  static let shared = AppState()
  
  // 开机自启
  @AppStorage("startUp") var startUp: Bool = false
  
  // Runner
  @AppStorage("runnerSpeed") var runnerSpeed = 0.5
  @AppStorage("speedProportional") var speedProportional = true
  @AppStorage("runnerId") var runnerId: String = ""
  
  // Hidder
  @AppStorage("showHidder") var showHidder: Bool = false
  
  // Texter
  @AppStorage("showTexter") var showTexter: Bool = false
  @AppStorage("showShimmer") var showShimmer: Bool = true
  @AppStorage("colorIndex") var colorIndex: Int = 0
  @AppStorage("text") var text: String = String(localized: "Keep happy.")
  
  
  // Paster
  @AppStorage("showPaster") var showPaster: Bool = false
  @AppStorage("historyCount") var historyCount: Int = 20
}
