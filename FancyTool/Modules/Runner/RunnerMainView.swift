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
  @State private var lastFactor: Float?
  @State private var currentRunner: RunnerModel? = nil
  
  init(height: CGFloat) {
    self.height = height
    _currentRunner = State(initialValue: RunnerHandler.shared.getRunnerById(AppState.shared.runnerId))
  }
  
  // 辅助函数
  private func clamp<T: Comparable>(_ value: T, lowerBound: T, upperBound: T) -> T {
    min(max(value, lowerBound), upperBound)
  }
  
  var body: some View {
    
    // CPU 使用率百分比 (0-100)
    let speedFactor = Double(cpuUtil.cpuUsage) / 100.0
    let factor = Float((1 - speedFactor) * (1.1 - state.runnerSpeed) / 5)

    // 3FPS ~ 15FPS
    let minInterval: Float = 1.0 / 3.0
    let maxInterval: Float = 1.0 / 15.0
    let clampFactor: Float = clamp(factor, lowerBound: minInterval, upperBound: maxInterval)
    
    VStack{
      RunnerView(
        runner: currentRunner,
        factor: clampFactor,
        isRunning: true
      )
      .frame(height: height)
      .aspectRatio(contentMode: .fit)
      
    }
    .onChange(of: state.runnerId) {
      currentRunner = RunnerHandler.shared.getRunnerById(state.runnerId)
    }
    .onChange(of: cpuUtil.cpuUsage) { _, newUsage in
      // 计算新的factor
      let speedFactor = Double(newUsage) / 100.0
      let newFactor = Float((1 - speedFactor) * (1.1 - state.runnerSpeed) / 5)
      let clampedFactor = clamp(newFactor, lowerBound: minInterval, upperBound: maxInterval)
      
      // 只有当变化超过0.05时才更新（避免微小波动）
      if lastFactor == nil || abs(clampedFactor - lastFactor!) > 0.05 {
        lastFactor = clampedFactor
      }
    }
  }
}


