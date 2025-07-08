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
  
  let container: ModelContainer
  static let shared = RunnerHandler()
  private(set) var cachedRunners: [RunnerModel] = []
  
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
      
    } catch {
      fatalError("Failed to create model container: \(error)")
    }
    
    // 异步填充默认数据
    Task { @MainActor in
      let context = container.mainContext
      _ = fillWithDefaultRunner(context: context)
      cachedRunners = try! context.fetch(FetchDescriptor<RunnerModel>())
    }
  }
  
  // id 查询
  func getRunnerById(_ id: String) -> RunnerModel? {
    return cachedRunners.first { $0.id.uuidString == id }
  }
  
  // 默认 Runner 配置
  let defaultRunners: [String: (String, String)] = [
    "fish": ("10001b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "fish2": ("10002b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "rock": ("10003b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "gold": ("10004b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    
    
    "sheep": ("20001b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "sheep2": ("20002b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "sheep3": ("20003b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "explosion": ("20004b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    
    "bushe": ("30001b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "bushe2": ("30002b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "bushe3": ("30003b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    
    "tree": ("40001b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "tree2": ("40002b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "tree3": ("40003b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "tree4": ("40004b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    
    "run": ("50001b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "run2": ("50002b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "run3": ("50003b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "run4": ("50004b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    
  ]
  
  func fillWithDefaultRunner(context: ModelContext) -> Int {
    guard let urls = Bundle.main.urls(forResourcesWithExtension: "gif", subdirectory: nil) else {
      print("No GIF resources found in the bundle.")
      return 0
    }
    
    print("fill with default runner")
    
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
