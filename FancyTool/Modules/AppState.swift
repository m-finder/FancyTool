//
//  AppState.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/7.
//

import SwiftUI
class AppState : ObservableObject{
  
  static let shared = AppState()
  
  // 开机自启
  @AppStorage("startUp") var startUp: Bool = false
  
  // Runner
  @AppStorage("runnerSpeed") var runnerSpeed = 0.5
  @AppStorage("speedProportional") var speedProportional = true
  @AppStorage("runnerId") var runnerId: String = "10001b46-eb35-4625-bb4a-bc0a25c3310b"
  
  // Hidder
  @AppStorage("showHidder") var showHidder: Bool = false
  
  // Texter
  @AppStorage("texter") var texter: String = String(localized: "Drink more water.")
  
}
