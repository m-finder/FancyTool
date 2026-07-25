//
//  HiderSettingView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2026/7/24.
//

import SwiftUI
import Combine

struct HidderSettingView: View {
  
  @ObservedObject var state = AppState.shared
  @State private var radiusDebouncer: AnyCancellable?
  @State private var hidderSizeDebouncer: AnyCancellable?
  
    var body: some View {
      
      LabeledContent(String(localized: "Hidder size:")) {
        HStack {
          Slider(
            value: Binding(
              get: { Double(state.hidderSize) },
              set: { state.hidderSize = Int($0) }
            ),
            in: 5...10,
            step: 1
          ).frame(width: 150)
          
          Text("\(state.hidderSize)").frame(width: 30)
        }
        .onChange(of: state.hidderSize) { oldValue, newValue in
          hidderSizeDebouncer?.cancel()
          hidderSizeDebouncer = Just(newValue)
            .delay(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { _ in Hidder.shared.refresh() }
        }
      }
    }
}

#Preview {
    HidderSettingView()
}
