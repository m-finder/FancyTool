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
    "whale": ("10001b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "whale2": ("10002b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "sheep": ("10003b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "sheep2": ("10004b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    
    "bushe": ("20001b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "bushe2": ("20002b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "bushe3": ("20003b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "bushe4": ("20004b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    
    "tree": ("30001b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "tree2": ("30002b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "tree3": ("30003b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "tree4": ("30004b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    
    "rock": ("40001b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "gold": ("40002b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "big-guy": ("40003b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "bird2": ("40004b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
  
    "sleep": ("60001b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "happy": ("60002b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "love": ("60003b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "sleep-cat": ("60004b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    
    "man": ("70001b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "bear": ("70002b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "tree-grass": ("70003b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "sun": ("70004b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
 
    "bat": ("90001b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "bird": ("90002b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "dragon": ("90003b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "phoenix": ("90004b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
  ]
  
  init() {
    
    let container = try! ModelContainer(for: RunnerModel.self)
    modelContext = ModelContext(container)
    
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
