//
//  RunnerView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/2.
//

import SwiftUI
import SwiftData

struct RunnerView: View {
  
  @AppStorage("currentImageId") private var currentImageId: String = "A1AF9595-F3FC-4A4F-A134-8F9CED4B761D"
  
  @StateObject var cpuUtil = CpuUtil()
  @AppStorage("runnerSpeed") private var runnerSpeed = 0.5
  @AppStorage("speedProportional") private var speedProportional = true
  
  // 优化查询：只获取当前选中的Runner
  @Query private var runners: [RunnerModel]
  private var currentRunner: RunnerModel? {
    guard let uuid = UUID(uuidString: currentImageId) else { return nil }
    let runner = runners.first { $0.id == uuid }
    return runner
  }
  
  var body: some View {
    let cpuUsage = Double(cpuUtil.cpuUsage) // CPU使用率百分比 (0-100)
    let speedFactor = speedProportional ? (1.0 - cpuUsage/100.0) : (cpuUsage/100.0)
    let factor = Float(speedFactor / 5 * (1.1 - runnerSpeed))
    let minInterval: Float = 0.012
    let clampedFactor = clamp(factor, lowerBound: minInterval, upperBound: 0.5) // 设置上限避免过快
    
    MainView(
      runner: currentRunner,
      factor: clampedFactor,
    )
  }
}

struct MainView: View {
  
  var runner: RunnerModel?
  var factor: Float
  var autoReverse = true
  
  @State private var direction = 1
  @State private var imageIndex = 0
  
  
  var body: some View {
    
    let timer = Timer.publish(every: TimeInterval(factor), on: .main, in: .common).autoconnect()
    
    VStack {
      if runner != nil {
        Image(runner!.getImage(imageIndex), scale: 1, label: Text("RunnerView")).resizable()
      } else {
        Image("AppIcon").resizable()
      }
    }.onReceive(timer) { _ in
      guard let frame_number = runner?.frame_number else {
        return
      }
      
      if imageIndex == 0 {
        direction = 1
      }
      
      if imageIndex >= frame_number - 1 {
        if autoReverse {
          direction = -1
        } else {
          direction = 1
          imageIndex = 0
        }
      }
      
      imageIndex += direction
    }.onChange(of: runner) {
      imageIndex = 0
      direction = 1
    }
  }
}

// 辅助函数
func clamp<T: Comparable>(_ value: T, lowerBound: T, upperBound: T) -> T {
  min(max(value, lowerBound), upperBound)
}
