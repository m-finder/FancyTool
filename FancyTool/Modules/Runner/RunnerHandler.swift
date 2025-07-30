//
//  Handler.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import AppKit
import SwiftData

class RunnerHandler {
  
  static let shared = RunnerHandler()
  private var modelContext: ModelContext
  private(set) var cachedRunners: [RunnerModel] = []
  
  private var defaultRunners: [String: (String, String)] = [
    "1": ("10000b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "2": ("10001b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "3": ("10002b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "4": ("10003b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
  ]
  
  init() {
        
    let container = try! ModelContainer(for: RunnerModel.self)
    modelContext = ModelContext(container)
    
    // 清空
    cachedRunners = try! modelContext.fetch(FetchDescriptor<RunnerModel>())
    for runner in cachedRunners {
        modelContext.delete(runner)
    }
    cachedRunners = []
   
    guard let urls = Bundle.main.urls(forResourcesWithExtension: "gif", subdirectory: nil) else {
      print("No GIF resources found in the bundle.")
      return
    }
    
    var count = 0
    
    for url in urls {
      let name = url.deletingPathExtension().lastPathComponent
      
      guard let conf = defaultRunners[name] else {
        continue
      }
      
      let id = UUID(uuidString: conf.0)!
      if !exist(id: id) {
        if let data = try? Data(contentsOf: url) {
          let runner = RunnerModel(
            id: id,
            isDefault: true,
            frameNumber: getFrameCount(data),
            data: data
          )
          modelContext.insert(runner)
          count += 1
        }
      }
    }
    
    do {
      try modelContext.save()
      cachedRunners = try! modelContext.fetch(FetchDescriptor<RunnerModel>())
    } catch {
      print("Gif Data Failed to save context: \(error)")
    }
    
    print("Runner Handler init")
  }
  
  private func exist(id: UUID) -> Bool {
    let descriptor = FetchDescriptor<RunnerModel>(predicate: #Predicate { $0.id == id })
    return (try? modelContext.fetchCount(descriptor)) ?? 0 > 0
  }
  
  private func getFrameCount(_ data: Data) -> Int {
    guard let imageSrc = CGImageSourceCreateWithData(data as CFData, nil) else { return 0 }
    return CGImageSourceGetCount(imageSrc)
  }
  
  public func getRunnerById(_ id: String) -> RunnerModel? {
    return cachedRunners.first { $0.id.uuidString == id }
  }
  
}
