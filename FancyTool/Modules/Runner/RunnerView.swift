//
//  RunnerView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/2.
//

import SwiftUI
import SwiftData
import Combine

struct RunnerView: View {
  
  @Environment(\.modelContext) private var modelContext
  @ObservedObject var state = AppState.shared
  
  @StateObject var cpuUtil = CpuUtil()
  
  @State var height: CGFloat
  
  init(height: CGFloat) {
    self.height = height
  }
  
  private let runners = RunnerHandler.shared.cachedRunners

  private var currentRunner: RunnerModel? {
    return RunnerHandler.shared.getRunnerById(state.runnerId)
  }
  
  var body: some View {
    
    // CPU 使用率百分比 (0-100)
    let cpuUsage = Double(cpuUtil.cpuUsage)
    let speedFactor = state.speedProportional ? (1.0 - cpuUsage / 100.0) : (cpuUsage / 100.0)
    let factor = Float(speedFactor / 5 * (1.1 - state.runnerSpeed))
    let minInterval: Float = 0.012
    
    // 设置上限避免过快，限制最大帧率（60FPS）
    let maxFPS: Float = 60.0
    let minFrameInterval = 1.0 / maxFPS
    let clampedFactor = clamp(factor, lowerBound: max(minInterval, minFrameInterval), upperBound: 0.5)
    
    MainView(
      runner: currentRunner,
      factor: clampedFactor,
      isRunning: true
    ).frame(height: height)
      .aspectRatio(contentMode: .fit)
  }
}

struct MainView: View {
  
  var runner: RunnerModel?
  var factor: Float
  var autoReverse = true
  var isRunning: Bool = false
  
  @State private var direction = 1
  @State private var imageIndex = 0
  
  @State private var frameUpdatePublisher = PassthroughSubject<Void, Never>()
  @State private var cancellable: AnyCancellable?
  
  var body: some View {
    
    VStack {
      
      if let runner = runner {
        
        Image(
          runner.getImage(imageIndex),
          scale: 1,
          label: Text("RunnerView")
        ).interpolation(.high)
          .resizable()
          .aspectRatio(contentMode: .fit)
        
      } else {
        Image("default").resizable().aspectRatio(contentMode: .fit).scaledToFit()
      }
      
    }.onReceive(frameUpdatePublisher.throttle(for: .seconds(0.1), scheduler: RunLoop.main, latest: true)) { _ in
      
      updateFrame()
      
    }.onAppear {
      
      cancellable = Timer.publish(
        every: TimeInterval(factor),
        on: .main,
        in: .common
      ).autoconnect().sink { _ in
        frameUpdatePublisher.send()
      }
      
      
    }.onDisappear {
      
      cancellable?.cancel()
      
    }
    
  }
  
  private func updateFrame() {
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
  }
}

// 辅助函数
func clamp<T: Comparable>(_ value: T, lowerBound: T, upperBound: T) -> T {
  min(max(value, lowerBound), upperBound)
}

