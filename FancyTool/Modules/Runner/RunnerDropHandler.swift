//
//  RunnerDropHandler.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/8/18.
//

import SwiftUI
import UniformTypeIdentifiers

struct RunnerDropHandler :DropDelegate{
  
  @Binding var isDragging: Bool
  private let onComplete: (Data) -> Void
  
  init(isDragging: Binding<Bool>, onComplete: @escaping (Data) -> Void) {
    self._isDragging = isDragging
    self.onComplete = onComplete
  }
  
  func performDrop(info: DropInfo) -> Bool {
    isDragging = false
    
    // 处理拖放的文件
    let itemProviders = info.itemProviders(for: [.fileURL])
    for itemProvider in itemProviders {
      _ = itemProvider.loadObject(ofClass: URL.self) { url, error in
        guard let url = url, error == nil else { return }
        
        // 验证是否为GIF文件
        if url.pathExtension.lowercased() == "gif" {
          do {
            let data = try Data(contentsOf: url)
            DispatchQueue.main.async {
              self.onComplete(data)
            }
          } catch {
            print("Error reading GIF file: \(error.localizedDescription)")
          }
        }
      }
    }
    return true
  }
  
  func dropEntered(info: DropInfo) {
    isDragging = true
  }
  
  func dropExited(info: DropInfo?) {
    isDragging = false
  }
  
  func dropUpdated(info: DropInfo) -> DropProposal? {
    return DropProposal(operation: .copy)
  }
}
