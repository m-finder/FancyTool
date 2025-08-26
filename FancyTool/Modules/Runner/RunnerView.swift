//
//  RunnerView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//
import SwiftUI
import SwiftData
import Combine

struct RunnerView: View {
  
  var runner: RunnerModel?
  var factor: Float
  var autoReverse = false
  var isRunning: Bool = false
  
  @State private var direction = 1
  @State private var imageIndex = 0
  @State private var timer: AnyCancellable?
  
  // 开始计时器
  private func startTimer() {
    
    guard isRunning else { return }
    
    let interval = TimeInterval(factor)
    
    // 创建定时器并设置宽容度（减少唤醒频率）
    timer = Timer.publish(every: interval, tolerance: interval * 0.1, on: .main, in: .common)
      .autoconnect()
      .sink { _ in
        guard let frameNumber = runner?.frameNumber else { return }
       
        if imageIndex == 0 {
          direction = 1
        }
        if imageIndex >= frameNumber - 1 {
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
  
  var body: some View {

    VStack {
      
      if let runner = runner {
        Image(
          runner.getImage(imageIndex),
          scale: 1,
          label: Text("RunnerView")
        )
        .interpolation(.high)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .onAppear {
          startTimer()
        }
        .onDisappear {
          timer?.cancel()
        }
        .onChange(of: factor) {
          timer?.cancel()
          startTimer()
        }
        .onChange(of: runner) {
          imageIndex = 0
          timer?.cancel()
          startTimer()
        }
        
      } else {
        Image("default").resizable().aspectRatio(contentMode: .fit).scaledToFit()
      }
    }
  }
}


