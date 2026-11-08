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
  
  private let columns = Array(repeating: GridItem(.flexible(minimum: 0), spacing: 10), count: 4)
  
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
        VStack(alignment: .leading, spacing: 10) {
          Toggle("Status pup", isOn: state.$runnerCompanion)
            .toggleStyle(.switch)
            .onChange(of: state.runnerCompanion) { Runner.shared.change() }
          Text("A little dog that rests, plays and keeps you company.")
            .font(.caption)
            .foregroundStyle(.secondary)
          HStack(spacing: 8) {
            ForEach([RunnerCompanionState.idle, .busy, .charging, .sleeping], id: \.self) { mood in
              VStack(spacing: 4) {
                if let image = RunnerCompanionArt.frame(state: mood, index: RunnerCompanionArt.previewIndex(for: mood), scale: 2) {
                  Image(decorative: image, scale: 2)
                    .interpolation(.none)
                    .frame(height: 26)
                }
                Text(mood.title).font(.system(size: 10))
              }
              .frame(maxWidth: .infinity)
            }
          }
          if state.runnerCompanion {
            Text("Click to spin · Right-click for menu")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Divider()
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 12)
        /* 关键：用 LazyVGrid 代替 FlowStack */
        LazyVGrid(columns: columns, spacing: 10) {
          
          /* 拖放入口始终放在第一个格子 */
          RunnerDropView()
            .frame(maxWidth: 90, maxHeight: 90)
            .aspectRatio(1, contentMode: .fit)
          
          /* 后面跟着所有 runner */
          ForEach(runners) { runner in
            ZStack(alignment: .bottomTrailing) {
              VStack {
                RunnerView(
                  runner: runner,
                  factor: state.runnerId == runner.id.uuidString ? 0.5 : 1,
                  isRunning: !state.runnerCompanion && state.runnerId == runner.id.uuidString
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .cornerRadius(8)
                .scaledToFit()
              }
              .background(Color.secondary.colorInvert())
              .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
              .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                  .stroke(
                    !state.runnerCompanion && state.runnerId == runner.id.uuidString ? Color.accentColor : Color.clear,
                    lineWidth: 1
                  )
              )
              
              if !runner.isDefault {
                RunnerRemoveView(id: runner.id)
              }
            }
            .frame(maxWidth: 90, maxHeight: 90)
            .aspectRatio(1, contentMode: .fit)
            .contentShape(RoundedRectangle(cornerRadius: 5))
            .onTapGesture {
              let wasCompanion = state.runnerCompanion
              state.runnerCompanion = false
              state.runnerId = !wasCompanion && state.runnerId == runner.id.uuidString ? "" : runner.id.uuidString
              Runner.shared.change()
            }
            .id(runner.id.uuidString)
          }
        }
        .padding(.horizontal, 10)
      }
      // Keep the fourth column clear of a permanently visible scrollbar.
      .contentMargins(.trailing, 18, for: .scrollContent)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
}

#Preview {
  RunnerSettingView()
}
