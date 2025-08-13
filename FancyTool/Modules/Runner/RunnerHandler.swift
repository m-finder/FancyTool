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
    "1": ("10001b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "2": ("10002b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "3": ("10003b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "4": ("10004b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "5": ("10005b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "6": ("10006b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "7": ("10007b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "8": ("10008b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "9": ("10009b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "10": ("10010b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "11": ("10011b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "12": ("10012b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "13": ("10013b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "14": ("10014b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "15": ("10015b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "16": ("10016b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "17": ("10017b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "18": ("10018b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "19": ("10019b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "20": ("10020b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "21": ("10021b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
  ]
  
  private init() {
        
    let container = try! ModelContainer(for: RunnerModel.self)
    modelContext = ModelContext(container)
    
    guard let urls = Bundle.main.urls(forResourcesWithExtension: "gif", subdirectory: nil) else {
      print("No GIF resources found in the bundle.")
      return
    }
    
    var count = 0
    
    // 清空
//    cachedRunners = try! modelContext.fetch(FetchDescriptor<RunnerModel>())
//    for runner in cachedRunners {
//        modelContext.delete(runner)
//    }
//    cachedRunners = []

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
