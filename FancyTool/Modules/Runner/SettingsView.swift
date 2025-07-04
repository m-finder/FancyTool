//
//  SettingsView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import SwiftUI
import ServiceManagement
import UniformTypeIdentifiers
import SwiftData

struct SettingsView: View {
  
  @Query(sort: \RunnerModel.id, order: .forward) private var runners: [RunnerModel]
  
  @AppStorage("currentRunnerId") private var currentRunnerId: String = "A3AF9595-F3FC-4A4F-A134-8F9CED4B761D"
  @AppStorage("startUp") var startUp: Bool = false
  
  @AppStorage("texter") var texter: String = String(localized: "Drink more water.")
  
  var body: some View {
    
    VStack(alignment: .center){
      Divider().padding(20)
      FlowStack(spacing: CGSize(width: 10, height: 10)){
        ForEach(runners) { runner in
          VStack {
            MainView(runner: runner, factor: currentRunnerId == runner.id.uuidString ? 0.1 : 0.2)
              .frame(width: 90, height: 90)
              .cornerRadius(8)
          }.padding(4)
            .background(Color.secondary.colorInvert())
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous)
              .stroke(currentRunnerId == runner.id.uuidString ? Color.accentColor : Color.clear, lineWidth: 2))
            .onTapGesture {
              currentRunnerId = runner.id.uuidString
            }.id(runner.id.uuidString)
        }
      }
    }
  }
}
