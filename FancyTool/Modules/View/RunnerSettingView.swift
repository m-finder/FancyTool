//
//  RunnerSettingView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/25.
//

import SwiftUI

struct RunnerSettingView: View {
  
  @ObservedObject var state = AppState.shared
  @StateObject private var runnerHandler = RunnerHandler.shared
  
  private let cardSize: CGFloat = 36
  private let columns = [GridItem(.adaptive(minimum: 36, maximum: 36), spacing: 4)]
  
  var body: some View {
    VStack(alignment: .center, spacing: 0) {
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          HStack(spacing: 8) {
            Toggle("Status pup", isOn: state.$runnerCompanion)
              .toggleStyle(.switch)
              .fixedSize()
              .onChange(of: state.runnerCompanion) { Runner.shared.change() }

            Divider().frame(height: 38)

            HStack(spacing: 4) {
              ForEach([RunnerCompanionState.idle, .busy, .charging, .sleeping], id: \.self) { mood in
                VStack(spacing: 1) {
                  if let image = RunnerCompanionArt.frame(
                    state: mood,
                    index: RunnerCompanionArt.previewIndex(for: mood),
                    scale: 3
                  ) {
                    Image(decorative: image, scale: 3)
                      .resizable()
                      .interpolation(.high)
                      .scaledToFit()
                      .frame(width: 30, height: 24)
                  }
                  Text(mood.title)
                    .font(.system(size: 9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity)
                .help(mood.title)
              }
            }
          }

          RunnerDropView()
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .modifier(RunnerCardSurface(colors: texterColors, isSelected: false))

          LazyVGrid(columns: columns, spacing: 5) {
            ForEach(runnerHandler.cachedRunners) { runner in
              ZStack(alignment: .bottomTrailing) {
                RunnerView(
                  runner: runner,
                  factor: state.runnerId == runner.id.uuidString ? RunnerConfig.previewFrameInterval : 1,
                  isRunning: !state.runnerCompanion && state.runnerId == runner.id.uuidString
                )
                .frame(width: 34, height: 32)

                if !runner.isDefault {
                  RunnerRemoveView(id: runner.id)
                }
              }
              .frame(width: cardSize, height: cardSize)
              .modifier(RunnerCardSurface(
                colors: texterColors,
                isSelected: !state.runnerCompanion && state.runnerId == runner.id.uuidString
              ))
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
          .padding(.vertical, 10)
        }
        .padding(.horizontal, 10)
      }
      // Keep the adaptive grid clear of the scroll indicator.
      .contentMargins(.trailing, 18, for: .scrollContent)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private var texterColors: [Color] {
    TexterPalette.colors(index: state.colorIndex, customData: state.customColorsData)
  }
}

struct RunnerCardSurface: ViewModifier {
  let colors: [Color]
  let isSelected: Bool

  private var palette: [Color] { colors.isEmpty ? [.accentColor, .cyan] : colors }

  func body(content: Content) -> some View {
    let startColor = palette.first ?? .accentColor
    let endColor = palette.last ?? .cyan
    let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)

    content
      .clipShape(shape)
      .background {
        shape.fill(LinearGradient(
          colors: [
            startColor.opacity(isSelected ? 0.14 : 0.05),
            endColor.opacity(isSelected ? 0.08 : 0.025)
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ))
      }
      .overlay {
        shape.stroke(
          LinearGradient(
            colors: palette.map { $0.opacity(isSelected ? 0.92 : 0.52) },
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          lineWidth: isSelected ? 1.8 : 1
        )
      }
      .shadow(
        color: startColor.opacity(isSelected ? 0.34 : 0.12),
        radius: isSelected ? 8 : 3
      )
  }
}

#Preview {
  RunnerSettingView()
}
