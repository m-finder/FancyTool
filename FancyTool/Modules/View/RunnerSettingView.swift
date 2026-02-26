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
  
  /* 每行 4 个 */
  private let columns = [
    GridItem(.fixed(90), spacing: 10),
    GridItem(.fixed(90), spacing: 10),
    GridItem(.fixed(90), spacing: 10),
    GridItem(.fixed(90), spacing: 10)
  ]
  
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
    VStack(alignment: .center, spacing: 0) {
      ScrollView {
        /* 关键：用 LazyVGrid 代替 FlowStack */
        LazyVGrid(columns: columns, spacing: 10) {
          
          /* 拖放入口始终放在第一个格子 */
          RunnerDropView().frame(width: 90, height: 90)
          
          /* 后面跟着所有 runner */
          ForEach(runners) { runner in
            ZStack(alignment: .bottomTrailing) {
              VStack {
                RunnerView(
                  runner: runner,
                  factor: state.runnerId == runner.id.uuidString ? 0.5 : 1,
                  isRunning: state.runnerId == runner.id.uuidString
                )
                .frame(width: 90, height: 90)
                .cornerRadius(8)
                .scaledToFit()
              }
              .background(Color.secondary.colorInvert())
              .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
              .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                  .stroke(
                    state.runnerId == runner.id.uuidString ? Color.accentColor : Color.clear,
                    lineWidth: 1
                  )
              )
              
              if !runner.isDefault {
                RunnerRemoveView(id: runner.id)
              }
            }
            .frame(width: 90, height: 90)
            .contentShape(RoundedRectangle(cornerRadius: 5))
            .onTapGesture {
              state.runnerId = state.runnerId == runner.id.uuidString ? "" : runner.id.uuidString
              Runner.shared.change()
            }
            .id(runner.id.uuidString)
          }
        }
        .padding(.horizontal, 10)
      }
      .frame(maxHeight: 400)
    }
    .frame(maxHeight: .infinity, alignment: .top)
  }
}

#Preview {
  RunnerSettingView()
}
