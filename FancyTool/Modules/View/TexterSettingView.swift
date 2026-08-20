//
//  TexterSettingView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2026/7/25.
//

import SwiftUI
import Combine

struct TexterSettingView: View {
  
  @ObservedObject var state = AppState.shared
  @State private var radiusDebouncer: AnyCancellable?
  @State private var fontSizeDebouncer: AnyCancellable?
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(String(localized: "Font size:"))
          .frame(width: 72, alignment: .leading)

        Slider(
          value: Binding(
            get: { Double(state.fontSize) },
            set: { state.fontSize = Int($0) }
          ),
          in: 12...16,
          step: 1
        )
        .frame(width: 150)
        
        Text("\(state.fontSize)")
          .frame(width: 24, alignment: .trailing)
      }
      .onChange(of: state.fontSize) { oldValue, newValue in
        fontSizeDebouncer?.cancel()
        fontSizeDebouncer = Just(newValue)
          .delay(for: .milliseconds(50), scheduler: RunLoop.main)
          .sink { _ in }
      }

      Toggle(String(localized: "Texter Shimmer"), isOn: state.$showShimmer)
        .onChange(of: state.showShimmer) { _, newValue in
          if newValue {
            state.rainbowShimmer = false
          }
          state.showShimmer = newValue
        }
        .toggleStyle(SwitchToggleStyle())

      Toggle(String(localized: "Rainbow Shimmer"), isOn: state.$rainbowShimmer)
        .onChange(of: state.rainbowShimmer) { _, newValue in
          if newValue {
            state.showShimmer = false
          }
          state.rainbowShimmer = newValue
        }
        .toggleStyle(SwitchToggleStyle())
    }
    .font(.system(size: 12))
    .frame(width: 270, alignment: .leading)
  }
}

#Preview {
  TexterSettingView()
}
