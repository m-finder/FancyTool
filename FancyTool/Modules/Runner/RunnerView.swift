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
        direction = 1
        imageIndex = 0
    }
    
    imageIndex += direction
  }
}


