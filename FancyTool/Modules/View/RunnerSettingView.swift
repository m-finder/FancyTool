//
//  RunnerSettingView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/25.
//

import SwiftUI

struct RunnerSettingView: View {
  
  // 按 UUID 的字符串表示排序
  private let runners = RunnerHandler.shared.cachedRunners.sorted { a, b in
    return a.id.uuidString < b.id.uuidString
  }
  
  @ObservedObject var state = AppState.shared
  
  var body: some View {
    VStack(alignment: .center, spacing: 0){
      ScrollView {
        FlowStack(spacing: CGSize(width: 10, height: 10)){
          ForEach(runners) { runner in
            
            VStack {
              
              RunnerView(
                runner: runner,
                factor: state.runnerId == runner.id.uuidString ? 0.1 : 0.2,
                isRunning: state.runnerId == runner.id.uuidString ? true : false
              ).frame(
                width: 90,
                height: 90
              ).cornerRadius(8)
                .scaledToFit()
              
            }
            .clipShape(RoundedRectangle(
              cornerRadius: 5,
              style: .continuous
            ))
            .overlay(
              RoundedRectangle(
                cornerRadius: 5,
                style: .continuous
              ).stroke(
                state.runnerId == runner.id.uuidString ? Color.accentColor : Color.clear,
                lineWidth: 2
              )
            )
            .onTapGesture {
              state.runnerId = state.runnerId == runner.id.uuidString ? "" : runner.id.uuidString
            }
            .background(Color.secondary.colorInvert())
            .id(runner.id.uuidString)
            
          }
        }
      }.frame(maxHeight: 400)
    }
    .frame(maxHeight: .infinity, alignment: .top)
  }
}

#Preview {
  RunnerSettingView()
}
