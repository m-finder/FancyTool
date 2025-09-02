//
//  RunnerView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

//import SwiftUI
//
//struct RunnerMainView: View {
//  
//  @State var height: CGFloat
//  @StateObject var cpuUtil = CpuUtil()
//  @ObservedObject var state = AppState.shared
//  @State private var currentRunner: RunnerModel? = nil
//  
//  init(height: CGFloat) {
//    self.height = height
//    _currentRunner = State(initialValue: RunnerHandler.shared.getRunnerById(AppState.shared.runnerId))
//  }
//  
//  private let runners = RunnerHandler.shared.cachedRunners
//  
//  var body: some View {
//    
//    let interval = Float(0.2 / max(1.0, min(20.0, cpuUtil.cpuUsage / 5.0)))
//    
//    VStack{
//      RunnerView(
//        runner: currentRunner,
//        interval: interval,
//        isRunning: true
//      )
//      .frame(height: height)
//      .aspectRatio(contentMode: .fit)
//      .onChange(of: state.runnerId) {
//        currentRunner = RunnerHandler.shared.getRunnerById(state.runnerId)
//      }
//    }
//  }
//}


