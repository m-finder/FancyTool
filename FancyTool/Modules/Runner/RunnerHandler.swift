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
    } catch {
      fatalError("Failed to create model container: \(error)")
    }
    
    // 异步填充默认数据
    Task { @MainActor in
      let context = container.mainContext
      _ = fillWithDefaultRunner(context: context)
      _ = createDefaultDiyRunner(context: context)
    }
  }
  
  // 默认 Runner 配置
  let defaultRunners: [String: (String, String)] = [
    "mario": ("A1AF9595-F3FC-4A4F-A134-8F9CED4B761D", "default"),
    "hello": ("A2AF9595-F3FC-4A4F-A134-8F9CED4B767D", "default"),
  ]
  
  func fillWithDefaultRunner(context: ModelContext) -> Int {
    guard let urls = Bundle.main.urls(forResourcesWithExtension: "gif", subdirectory: nil) else {
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
            type: conf.1,
            frame_number: getRealFrameCount(data),
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
      type: type,
      frame_number: getRealFrameCount(data),
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
  
  // 创建默认DIY跑者
  func createDefaultDiyRunner(context: ModelContext) -> RunnerModel {
    let descriptor = FetchDescriptor<RunnerModel>(
      predicate: #Predicate { $0.type == "diy" }
    )
    
    if let existingRunner = try? context.fetch(descriptor).first {
      return existingRunner
    }
    
    guard let url = Bundle.main.url(forResource: "mariohello", withExtension: "gif"),
          let data = try? Data(contentsOf: url) else {
      fatalError("无法找到默认资源文件")
    }
    
    return createNewRunner(
      context: context,
      id: UUID(),
      type: "diy",
      data: data
    )
  }
}

// RunnerModel 扩展方法
extension RunnerModel {
  
  private static var imageCache: [ObjectIdentifier: [Int: CGImage]] = [:]
  static var defaultImage = NSImage(named: "AppIcon")!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
  
  // 获取图像选项
  private func getImageOptions() -> [CFString: Any] {
    [
      kCGImageSourceShouldCache: kCFBooleanTrue as Any,
      kCGImageSourceTypeIdentifierHint: "public.gif" as CFString
    ]
  }
  
  // 获取CGImageSource
  private func getCGImageSource(_ data: Data?) -> CGImageSource? {
    guard let rawData = data else { return nil }
    return CGImageSourceCreateWithData(rawData as CFData, getImageOptions() as CFDictionary)
  }
  
  // 获取图像
  func getImage(_ index: Int) -> CGImage {
    // 创建对象唯一标识作为缓存键
    let objectId = ObjectIdentifier(self)
    
    // 确保索引有效
    var safeIndex = index
    if safeIndex >= frame_number || safeIndex < 0 {
      safeIndex = 0
    }
    
    // 尝试从缓存获取
    if let cachedImg = Self.imageCache[objectId]?[safeIndex] {
      return cachedImg
    }
    
    // 缓存未命中，创建新图像
    guard let imgSrc = getCGImageSource(data),
          let cgImage = CGImageSourceCreateImageAtIndex(imgSrc, safeIndex, getImageOptions() as CFDictionary) else {
      return Self.defaultImage
    }
    
    // 更新缓存
    if Self.imageCache[objectId] == nil {
      Self.imageCache[objectId] = [:]
    }
    Self.imageCache[objectId]?[safeIndex] = cgImage
    
    return cgImage
  }
}
