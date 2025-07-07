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
  
  @AppStorage("runnerId") private var runnerId: String = "10001b46-eb35-4625-bb4a-bc0a25c3310b"
  @AppStorage("startUp") var startUp: Bool = false
  
  @AppStorage("texter") var texter: String = String(localized: "Drink more water.")

  
  var body: some View {
    
    VStack(alignment: .center, spacing: 20){
      FlowStack(spacing: CGSize(width: 10, height: 10)){
        ForEach(runners) { runner in
          VStack {
            MainView(
              runner: runner,
              factor: runnerId == runner.id.uuidString ? 0.1 : 0.2,
              isRunning: runnerId == runner.id.uuidString ? true : false
            )
            .frame(width: 90, height: 90)
            .cornerRadius(8)
          }
          .background(Color.secondary.colorInvert())
          .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
          .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous)
            .stroke(runnerId == runner.id.uuidString ? Color.accentColor : Color.clear, lineWidth: 2))
          .onTapGesture {
            runnerId = runner.id.uuidString
          }.id(runner.id.uuidString)
        }
      }
    }.frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding()
    
    VStack(alignment: .center){
      Divider().padding(20)
      
      Toggle(String(localized: "Launch on Startup"), isOn: $startUp)
        .onChange(of: startUp) { _, newValue in
          if #available(macOS 13.0, *) {
            if newValue {
              if SMAppService.mainApp.status == .enabled {
                try? SMAppService.mainApp.unregister()
              }
              
              try? SMAppService.mainApp.register()
            } else {
              try? SMAppService.mainApp.unregister()
            }
          }
        }
        .toggleStyle(SwitchToggleStyle())
        .font(.system(size: 12))
      
      Button(String(localized: "Quit App")) {
        NSApplication.shared.terminate(nil)
      }
      .keyboardShortcut("q")
      .frame(width: 100, height: 40)
      .font(.body)
      .cornerRadius(10)
      
      Text("Made By M-finder 🚀")
        .font(.footnote)
        .fontWeight(.light)
        .padding(.top)
      
      VStack(spacing: 1){
        Text(String(localized: "The image is sourced from the internet."))
          .font(.footnote)
          .fontWeight(.light)
        Text(String(localized: "Please contact us for removal if it infringes any copyrights."))
          .font(.footnote)
          .fontWeight(.light)
      }.padding(.top)
        .padding(.bottom)
    }
  }
}
