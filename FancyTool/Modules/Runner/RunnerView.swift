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
  @AppStorage("currentImageId") private var currentImageId: String = "A1AF9595-F3FC-4A4F-A134-8F9CED4B761D"
  
  @StateObject var cpuUtil = CpuUtil()
  @AppStorage("runnerSpeed") private var runnerSpeed = 0.5
  @AppStorage("speedProportional") private var speedProportional = true
  
  @State var width: CGFloat
  @State var height: CGFloat
  
  init(width:CGFloat, height: CGFloat ) {
      self.width = width
      self.height = height
  }
  
  // private var currentRunner: RunnerModel? {
            
  //   get {
  //     guard let targetId = UUID(uuidString: currentImageId) else {
  //       print("Invalid currentImageId: \(currentImageId)")
  //       return nil
  //     }
      
  //     print("currentImageId: \(currentImageId)")
      
  //     let descriptor = FetchDescriptor<RunnerModel>(predicate: #Predicate { $0.id == targetId })
    
  //     // 执行查询
  //     do {
  //       if let fetchedRunner = try modelContext.fetch(descriptor).first {
  //               print("runner id: \(fetchedRunner.id)")
  //               print("runner isDefault: \(fetchedRunner.isDefault)")
  //               print("runner frameNumber: \(fetchedRunner.frameNumber)")
  //               print("runner data size: \(fetchedRunner.data.count) bytes")
  //               return fetchedRunner
  //           } else {
  //               print("未查询到任何 RunnerModel 对象。")
  //               return nil
  //           }
  //     } catch {
  //       fatalError("数据出现了问题: \(error)")
  //     }
  //   }
  // }
  @Query private var runners: [RunnerModel]
  private var currentRunner: RunnerModel? {
      return runners.first { $0.id?.uuidString == currentImageId }
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
    ).frame(width: width, height: height)
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
        Image("default").resizable()
      }
    }.onReceive(timer) { _ in
      guard let frame_number = runner?.frameNumber else {
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
