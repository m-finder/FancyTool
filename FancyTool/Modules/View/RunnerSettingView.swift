//
//  RunnerSettingView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/25.
//

import SwiftUI

struct RunnerSettingView: View {
  
  @State private var isDragging = false
  @State private var hoveredRunnerId: UUID? = nil
  @ObservedObject var state = AppState.shared
  @StateObject private var runnerHandler = RunnerHandler.shared
  
  private var runners: [RunnerModel] {
    runnerHandler.cachedRunners.sorted { a, b in
      if a.isDefault && b.isDefault {
        return a.id.uuidString < b.id.uuidString
      } else if a.isDefault {
        return true
      } else if b.isDefault {
        return false
      } else {
        return a.createdAt < b.createdAt
      }
    }
  }
  
  var body: some View {
    VStack(alignment: .center, spacing: 0){
      ScrollView {
        FlowStack(spacing: CGSize(width: 10, height: 10)){
          
          RunnerDropView()
          
          ForEach(runners) { runner in
            // 使用带对齐参数的ZStack
            ZStack(alignment: .bottomTrailing) {
              VStack {
                RunnerView(
                  runner: runner,
                  interval: state.runnerId == runner.id.uuidString ? 0.5 : 1,
                  isRunning: state.runnerId == runner.id.uuidString ? true : false
                )
                .frame(width: 90, height: 90)
                .cornerRadius(8)
                .scaledToFit()
              }
              .background(Color.secondary.colorInvert())
              .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
              .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous).stroke(
                  state.runnerId == runner.id.uuidString ? Color.accentColor : Color.clear,
                  lineWidth: 1
                )
              )
              
              if !runner.isDefault {
                RunnerRemoveView(id: runner.id).offset(x: 0, y: 0)
              }
            }
            .frame(width: 90, height: 90)
            .contentShape(RoundedRectangle(cornerRadius: 5))
            .onTapGesture {
              state.runnerId = state.runnerId == runner.id.uuidString ? "" : runner.id.uuidString
            }
            .id(runner.id.uuidString)
          }
        }
      }
      .frame(maxHeight: 400)
    }
    .frame(maxHeight: .infinity, alignment: .top)
  }
}

#Preview {
  RunnerSettingView()
}
