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
  
  @ObservedObject var state = AppState.shared

  // 按 UUID 的字符串表示排序
  private let runners = RunnerHandler.shared.cachedRunners.sorted { a, b in
      return a.id.uuidString < b.id.uuidString
  }
  
  var body: some View {
    
    VStack(alignment: .center, spacing: 20){
      FlowStack(spacing: CGSize(width: 10, height: 10)){
        ForEach(runners) { runner in
          VStack {
            MainView(
              runner: runner,
              factor: state.runnerId == runner.id.uuidString ? 0.1 : 0.2,
              isRunning: state.runnerId == runner.id.uuidString ? true : false
            )
            .frame(width: 90, height: 90)
            .cornerRadius(8)
          }.background(Color.secondary.colorInvert())
            .clipShape(RoundedRectangle(
              cornerRadius: 5,
              style: .continuous
            ))
            .overlay(
              RoundedRectangle(
                cornerRadius: 5,
                style: .continuous
              ).stroke(
                state.runnerId == runner.id.uuidString ? Color.accentColor : Color.clear,
                lineWidth: 2
              )
            )
            .onTapGesture {
              if(state.runnerId == runner.id.uuidString){
                state.runnerId = ""
              }else{
                state.runnerId = runner.id.uuidString
              }
            }.id(runner.id.uuidString)
        }
      }
    }.frame(maxWidth: .infinity, maxHeight: .infinity).padding()
    
    
    
    VStack(alignment: .center){
      
      Divider().padding(20)
      
      Toggle(
        String(localized: "Launch on Startup"),
        isOn: state.$startUp
      ).onChange(of: state.startUp) { _, newValue in
        
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
        
        }.toggleStyle(SwitchToggleStyle())
        .font(.system(size: 12))
      
      Button(String(localized: "Quit App")) {
        NSApplication.shared.terminate(nil)
      }.keyboardShortcut("q")
      .frame(width: 100, height: 40)
      .font(.body)
      .cornerRadius(10)
      
      Text("© FancyTool by M-finder 2025")
        .font(.footnote)
        .fontWeight(.light)
        .padding(.top)
        .padding(.bottom)
    }
  }
}
