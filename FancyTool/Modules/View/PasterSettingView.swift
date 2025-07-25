//
//  PasterSettingView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/25.
//

import SwiftUI
import KeyboardShortcuts

struct PasterSettingView: View {
  
  @ObservedObject var state = AppState.shared
  
  var body: some View {
    
    VStack(alignment: .center, spacing: 0){

        LabeledContent(String(localized: "Number of records:")){
          TextField(
            "",
            value: $state.historyCount,
            format: .number
          )
          .onChange(of: state.historyCount) { _, newValue in
            state.historyCount = min(200, max(1, newValue))
          }
          .frame(width: 150)
          .textFieldStyle(.roundedBorder)
        }
        .padding()

        KeyboardShortcuts.Recorder("Shortcut:", name: .paster)
    }
    .frame(maxHeight: .infinity, alignment: .top)
    .font(.system(size: 12))
  }
}

#Preview {
  PasterSettingView()
}
