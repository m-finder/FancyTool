//
//  RunnerView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//
import SwiftUI
import SwiftData
import Combine

struct RunnerDropView: View {

  @State private var isDragging = false
  @StateObject private var runnerHandler = RunnerHandler.shared
  
  var body: some View {
    
    VStack {
      Image(systemName: "plus.circle.fill").font(.title).foregroundColor(Color.gray)
      Text(String(localized: "Drag and drop GIF here.")).font(.caption).foregroundColor(Color.gray)
    }
    .frame(width: 90,height: 90)
    .cornerRadius(8)
    .clipShape(RoundedRectangle(
      cornerRadius: 5,
      style: .continuous
    ))
    .onDrop(of: [.fileURL], delegate: RunnerDropHandler(isDragging: $isDragging) { data in
      runnerHandler.addRunner(gifData: data)
    })
    .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).stroke(Color.gray, lineWidth: 1))
    .background(Color.secondary.colorInvert())
    .scaledToFit()
    
  }
}


