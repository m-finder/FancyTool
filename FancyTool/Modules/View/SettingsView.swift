//
//  SettingsView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import SwiftUI
import ServiceManagement
import KeyboardShortcuts
import SwiftData

struct SettingsView: View {
  
  @ObservedObject var state = AppState.shared
  
  // 按 UUID 的字符串表示排序
  private let runners = RunnerHandler.shared.cachedRunners.sorted { a, b in
    return a.id.uuidString < b.id.uuidString
  }
  
  var body: some View {
    VStack(alignment: .center, spacing: 20){
      
      TabView{
        
        MainSettingView().tabItem {
          Text("Main")
        }
        
        VStack(alignment: .center, spacing: 20){
          FlowStack(spacing: CGSize(width: 10, height: 10)){
            ForEach(runners) { runner in
              
              VStack {
                
                RunnerView(
                  runner: runner,
                  factor: state.runnerId == runner.id.uuidString ? 0.1 : 0.2,
                  isRunning: state.runnerId == runner.id.uuidString ? true : false
                ).frame(
                  width: 90,
                  height: 90
                ).cornerRadius(8)
                  .scaledToFit()
                
              }.clipShape(RoundedRectangle(
                  cornerRadius: 5,
                  style: .continuous
                )).overlay(
                  RoundedRectangle(
                    cornerRadius: 5,
                    style: .continuous
                  ).stroke(
                    state.runnerId == runner.id.uuidString ? Color.accentColor : Color.clear,
                    lineWidth: 2
                  )
                ).onTapGesture {
                  state.runnerId = state.runnerId == runner.id.uuidString ? "" : runner.id.uuidString
                }.background(Color.secondary.colorInvert())
                .id(runner.id.uuidString)
              
            }
          }
        }.frame(
          maxWidth: .infinity,
          maxHeight: .infinity
        ).padding().tabItem {
            Text(String(localized: "Runner"))
          }
        
        VStack(alignment: .center){
          ZStack {
            HStack(alignment: .center, spacing: 3) {
              Toggle(
                String(localized: "Shimmer"),
                isOn: state.$showShimmer
              ).onChange(of: state.showShimmer) { _, newValue in
                state.showShimmer = newValue
              }.toggleStyle(SwitchToggleStyle())
                .font(.system(size: 12))
                .padding()
            }.padding()
          }.padding([.leading, .trailing], 25)
      
        }.tabItem {
          Text(String(localized: "Texter"))
        }
        
        
        VStack(alignment: .center){
          ZStack {
            HStack(alignment: .center, spacing: 3) {
              Text(String(localized: "Number of records.")).font(.body)
              Spacer()
              TextField(
                  String(localized: "Input something"),
                  value: $state.historyCount,
                  format: .number
              ).textFieldStyle(.roundedBorder)
            }.padding()
          }.padding([.leading, .trailing], 25)
          
          Form {
            KeyboardShortcuts.Recorder("Shortcut:", name: .paster)
          }.padding()
       
        }.tabItem {
          Text(String(localized: "Paster"))
        }
        
        
      }
    }.frame(
      maxWidth: .infinity,
      maxHeight: .infinity
    ).padding()

    CopyrightView()
  }
}

struct SettingsView_Previews: PreviewProvider {
  static var previews: some View {
    SettingsView()
  }
}
