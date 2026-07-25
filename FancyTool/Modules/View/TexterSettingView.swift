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

      LabeledContent(String(localized: "Font size:")) {
        HStack {
          Slider(
            value: Binding(
              get: { Double(state.fontSize) },
              set: { state.fontSize = Int($0) }
            ),
            in: 12...16,
            step: 1
          ).frame(width: 150)
          
          Text("\(state.fontSize)").frame(width: 30)
        }
        .onChange(of: state.fontSize) { oldValue, newValue in
          fontSizeDebouncer?.cancel()
          fontSizeDebouncer = Just(newValue)
            .delay(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { _ in }
        }
      }
      
    }
}

#Preview {
    TexterSettingView()
}
