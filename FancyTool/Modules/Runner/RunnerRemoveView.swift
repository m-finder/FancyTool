//
//  RunnerView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//
import SwiftUI

struct RunnerRemoveView: View {
  
  
  var id: UUID?
  @ObservedObject var state = AppState.shared
  @State private var hoveredRunnerId: UUID? = nil
  @StateObject private var runnerHandler = RunnerHandler.shared
  
  var body: some View {
    if let id = id {
      Button(
        action: {
          
          DispatchQueue.main.async {
            runnerHandler.removeRunner(id: id)
            if state.runnerId == id.uuidString {
              state.runnerId = ""
            }
          }
        },
        label: {
          Image(systemName: "xmark.circle.fill")
            .foregroundColor(.red)
            .background(Color.white.opacity(0.8))
            .clipShape(Circle())
        }
      )
      .buttonStyle(PlainButtonStyle())
      .zIndex(1)
      .frame(width: 24, height: 24)
      .contentShape(Circle())
    }
  }
}


