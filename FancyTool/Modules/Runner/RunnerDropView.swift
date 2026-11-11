//
//  RunnerView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//
import SwiftUI

struct RunnerDropView: View {

  @StateObject private var runnerHandler = RunnerHandler.shared
  
  var body: some View {
    
    VStack {
      if runnerHandler.isImporting { ProgressView().controlSize(.small) }
      else { Image(systemName: "plus.circle.fill").font(.title).foregroundColor(Color.gray) }
      Text(String(localized: "Drag and drop GIF here.")).font(.caption).foregroundColor(Color.gray)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .cornerRadius(8)
    .clipShape(RoundedRectangle(
      cornerRadius: 5,
      style: .continuous
    ))
    .onDrop(of: [.fileURL], delegate: RunnerDropHandler { url in
      runnerHandler.addRunner(url: url)
    })
    .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).stroke(Color.gray, lineWidth: 1))
    .background(Color.secondary.colorInvert())
    .alert("Could not import GIF", isPresented: Binding(
      get: { runnerHandler.importError != nil }, set: { if !$0 { runnerHandler.importError = nil } }
    )) {
      Button("OK") { runnerHandler.importError = nil }
    } message: { Text(runnerHandler.importError ?? "") }
    
  }
}


