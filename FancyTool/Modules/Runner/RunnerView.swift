//
//  RunnerView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/2.
//

import SwiftUI
import SwiftData

struct RunnerView: View {
  
  @Environment(\.modelContext) private var modelContext
  
  @StateObject var cpuUtil = CpuUtil()
  @AppStorage("runnerSpeed") private var runnerSpeed = 0.5
  @AppStorage("speedProportional") private var speedProportional = true
  
  @State var height: CGFloat
  @Binding var runnerId: String
  
  init(height: CGFloat, runnerId: Binding<String>) {
    self.height = height
    self._runnerId = runnerId
  }
  
  @Query private var runners: [RunnerModel]
  private var currentRunner: RunnerModel? {
    return runners.first { $0.id.uuidString == runnerId }
  }
  
  var body: some View {
    // CPU使用率百分比 (0-100)
    let cpuUsage = Double(cpuUtil.cpuUsage)
    let speedFactor = speedProportional ? (1.0 - cpuUsage/100.0) : (cpuUsage/100.0)
    let factor = Float(speedFactor / 5 * (1.1 - runnerSpeed))
    let minInterval: Float = 0.012
    // 设置上限避免过快
    let clampedFactor = clamp(factor, lowerBound: minInterval, upperBound: 0.5)
    
    MainView(
      runner: currentRunner,
      factor: clampedFactor,
      isRunning: true
    ).frame(height: height).aspectRatio(contentMode: .fit)
  }
}

struct MainView: View {
  
  var runner: RunnerModel?
  var factor: Float
  var autoReverse = true
  var isRunning: Bool = false
  
  @State private var direction = 1
  @State private var imageIndex = 0
  
  var body: some View {
    
    let timer = Timer.publish(every: TimeInterval(factor), on: .main, in: .common).autoconnect()
    
    VStack {
      if runner != nil {
        Image(runner!.getImage(imageIndex), scale: 1, label: Text("RunnerView")).resizable().aspectRatio(contentMode: .fit)
        .scaledToFit()
      } else {
        Image("default").resizable().aspectRatio(contentMode: .fit).scaledToFit()
      }
    }.onReceive(timer) { _ in
      guard isRunning, let frame_number = runner?.frameNumber else {
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
