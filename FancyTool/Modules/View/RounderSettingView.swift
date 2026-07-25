//
//  RounderSettingView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2026/7/24.
//

import SwiftUI
import Combine

struct RounderSettingView: View {
  
  @ObservedObject var state = AppState.shared
  @State private var radiusDebouncer: AnyCancellable?
  
    var body: some View {
      LabeledContent(String(localized: "Radius size:")) {
        HStack {
          Slider(
            value: Binding(
              get: { Double(state.radius) },
              set: { state.radius = CGFloat($0) }
            ),
            in: 10...25,
            step: 1
          )
          .frame(width: 150)
          
          Text(String(format: "%.1f", state.radius)).frame(width: 30)
        }
        .onChange(of: state.radius) { oldValue, newValue in
          radiusDebouncer?.cancel()
          radiusDebouncer = Just(newValue)
            .delay(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { Rounder.shared.refresh(CGFloat($0)) }
        }
      }
    }
}

#Preview {
    RounderSettingView()
}
