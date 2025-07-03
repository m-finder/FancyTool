//
//  RunnerHandler.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/2.
//

import Foundation
import AppKit
import SwiftData

class RunnerHandler {
  
  static let shared = RunnerHandler()
  let container: ModelContainer
  
  init(inMemory: Bool = false) {
    do {
      
      
      // 配置容器选项
      var configuration = ModelConfiguration(for: RunnerModel.self)
      if inMemory {
        configuration = ModelConfiguration(for: RunnerModel.self, isStoredInMemoryOnly: true)
      }
      
      container = try ModelContainer(
        for: RunnerModel.self,
        configurations: configuration
      )
      
      print("RunnerHandler 的 ModelContainer 地址: \(Unmanaged.passUnretained(container).toOpaque())")
      
    } catch {
      fatalError("Failed to create model container: \(error)")
    }
    
    // 异步填充默认数据
    Task { @MainActor in
      let context = container.mainContext
      _ = fillWithDefaultRunner(context: context)
    }
  }
  
  // 默认 Runner 配置
  let defaultRunners: [String: (String, String)] = [
    "mario": ("A1AF9595-F3FC-4A4F-A134-8F9CED4B761D", "default"),
    "hello": ("A2AF9595-F3FC-4A4F-A134-8F9CED4B767D", "default"),
  ]
  
  func fillWithDefaultRunner(context: ModelContext) -> Int {
    guard let urls = Bundle.main.urls(forResourcesWithExtension: "gif", subdirectory: nil) else {
      print("No GIF resources found in the bundle.")
      return 0
    }
    
    var count = 0
    
    for url in urls {
      let name = url.deletingPathExtension().lastPathComponent
      guard let conf = defaultRunners[name] else {
        continue
      }
      
      // 检查是否已存在
      let id = UUID(uuidString: conf.0)!
      if !runnerExists(id: id, context: context) {
        if let data = try? Data(contentsOf: url) {
          let runner = RunnerModel(
            id: id,
            isDefault: true,
            frameNumber: getRealFrameCount(data),
            data: data
          )
          context.insert(runner)
          count += 1
        }
      }
    }
    
    // 保存上下文
    do {
      try context.save()
    } catch {
      print("Failed to save context: \(error)")
    }
    
    return count
  }
  
  // 检查实体是否存在
  func runnerExists(id: UUID, context: ModelContext) -> Bool {
    let descriptor = FetchDescriptor<RunnerModel>(predicate: #Predicate { $0.id == id })
    return (try? context.fetchCount(descriptor)) ?? 0 > 0
  }
  
  // 创建新的跑者实体
  func createNewRunner(context: ModelContext, id: UUID, type: String, data: Data) -> RunnerModel {
    let runner = RunnerModel(
      id: id,
      isDefault: true,
      frameNumber: getRealFrameCount(data),
      data: data
    )
    context.insert(runner)
    return runner
  }
  
  // 获取实际帧数
  private func getRealFrameCount(_ data: Data) -> Int {
    guard let imageSrc = CGImageSourceCreateWithData(data as CFData, nil) else { return 0 }
    return CGImageSourceGetCount(imageSrc)
  }
}
