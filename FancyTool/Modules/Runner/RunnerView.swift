//
//  RunnerView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import SwiftUI

struct RunnerView: View {
  
  var runner: RunnerModel?
  var interval: Float
  var isRunning: Bool = false
  
  @State private var direction = 1
  @State private var imageIndex = 0
  @State private var lastFactor: Float = 0
  @State private var animationTaskId: String?
  
  private func updateImageIndex() {
    guard let runner = runner else { return }
    let frameNumber = runner.frameNumber
    
    if imageIndex >= frameNumber - 1 {
      imageIndex = 0
    }
    imageIndex += direction
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
          if isRunning {
            let taskId = "runner_\(UUID().uuidString)"
            animationTaskId = taskId
            TaskManager.shared.addTask(id: taskId, interval: TimeInterval(interval), queue: .main) {
              self.updateImageIndex()
            }
          }
        }
        .onDisappear {
          if let taskId = animationTaskId {
            TaskManager.shared.removeTask(id: taskId)
          }
        }
        .onChange(of: interval) {
          if let taskId = animationTaskId {
            TaskManager.shared.updateTaskInterval(id: taskId, newInterval: TimeInterval(interval))
          }
        }
        .onChange(of: runner) {
          imageIndex = 0
        }
        .onChange(of: isRunning) {
          if let taskId = animationTaskId {
            if isRunning {
              TaskManager.shared.addTask(id: taskId, interval: TimeInterval(interval), queue: .main) {
                self.updateImageIndex()
              }
            } else {
              TaskManager.shared.removeTask(id: taskId)
            }
          }
        }
      } else {
        Image("default").resizable().aspectRatio(contentMode: .fit).scaledToFit()
      }
    }
  }
}


