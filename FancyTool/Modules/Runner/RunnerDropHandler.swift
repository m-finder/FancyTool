//
//  RunnerDropHandler.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/8/18.
//

import SwiftUI
import UniformTypeIdentifiers

struct RunnerDropHandler: DropDelegate {
  private let onComplete: (Data) -> Void

  init(onComplete: @escaping (Data) -> Void) {
    self.onComplete = onComplete
  }

  func performDrop(info: DropInfo) -> Bool {
    // 处理拖放的文件
    let itemProviders = info.itemProviders(for: [.fileURL])
    for itemProvider in itemProviders {
      _ = itemProvider.loadObject(ofClass: URL.self) { url, error in
        guard let url, error == nil else { return }
        
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

  func dropUpdated(info: DropInfo) -> DropProposal? {
    DropProposal(operation: .copy)
  }
}
