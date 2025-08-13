//
//  RunnerView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import SwiftUI

struct RunnerMainView: View {
  
  @State var height: CGFloat
  @StateObject var cpuUtil = CpuUtil()
  @ObservedObject var state = AppState.shared
  @State private var currentRunner: RunnerModel? = nil
  
  init(height: CGFloat) {
    self.height = height
    _currentRunner = State(initialValue: RunnerHandler.shared.getRunnerById(AppState.shared.runnerId))
  }
  
  var body: some View {
    
    // CPU 使用率百分比 (0-100)
    let speedFactor = Double(cpuUtil.cpuUsage) / 100.0
    let factor = Float((1 - speedFactor) * (1.1 - state.runnerSpeed) / 5)

    // 5FPS ~ 1FPS
    let minInterval: Float = 0.2
    let maxInterval: Float = 1.0
    let clampFactor: Float = clamp(factor, lowerBound: minInterval, upperBound: maxInterval)
    
    VStack{
      RunnerView(
        runner: currentRunner,
        factor: clampFactor,
        isRunning: true
      )
      .frame(height: height)
      .aspectRatio(contentMode: .fit)
      
    }.onChange(of: state.runnerId) {
      print("Runner ID changed to: \(state.runnerId)")
      currentRunner = RunnerHandler.shared.getRunnerById(state.runnerId)
    }
  }
}

// 辅助函数
func clamp<T: Comparable>(_ value: T, lowerBound: T, upperBound: T) -> T {
  min(max(value, lowerBound), upperBound)
}
