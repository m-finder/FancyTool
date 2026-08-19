//
//  Handler.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import AppKit
import SwiftData

@MainActor
class RunnerHandler :ObservableObject{

  static let shared = RunnerHandler()
  private var modelContext: ModelContext?
  @Published private(set) var cachedRunners: [RunnerModel] = []

  private var defaultRunners: [String: (String, String)] = [
    "1": ("10001b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "2": ("10002b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "3": ("10003b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "4": ("10004b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "5": ("10005b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "6": ("10006b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "7": ("10007b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
  ]

  private init() {
    do {
      // 两个模块共享同一个 default.store，必须在同一个 container 里注册
      // 全部 model 类型，否则 SwiftData 不会为后初始化的 model 建表。
      let container = try ModelContainer(for: RunnerModel.self, PasterModel.self)
      modelContext = ModelContext(container)
      seedDefaultRunners()
      reloadCachedRunners()
    } catch {
      print("Failed to initialize runner database: \(error)")
    }
  }

  private func seedDefaultRunners() {
    guard let modelContext else { return }

    guard let urls = Bundle.main.urls(forResourcesWithExtension: "gif", subdirectory: nil) else {
      return
    }

    for url in urls {
      let name = url.deletingPathExtension().lastPathComponent

      guard let conf = defaultRunners[name] else {
        continue
      }

      guard let id = UUID(uuidString: conf.0) else { continue }
      if !exist(id: id) {
        if let data = try? Data(contentsOf: url) {
          let runner = RunnerModel(
            id: id,
            isDefault: true,
            frameNumber: getFrameCount(data),
            data: data
          )
          modelContext.insert(runner)
        }
      }
    }

    do {
      try modelContext.save()
    } catch {
      print("Gif Data Failed to save context: \(error)")
    }
  }

  private func reloadCachedRunners() {
    guard let modelContext else {
      cachedRunners = []
      return
    }

    do {
      let allRunners = try modelContext.fetch(FetchDescriptor<RunnerModel>())
      cachedRunners = sorted(allRunners)
    } catch {
      print("Failed to load runners: \(error)")
    }
  }

  private func sorted(_ runners: [RunnerModel]) -> [RunnerModel] {
    runners.sorted { a, b in
      if a.isDefault && b.isDefault {
        return a.id.uuidString < b.id.uuidString
      } else if a.isDefault {
        return true
      } else if b.isDefault {
        return false
      } else {
        return a.createdAt < b.createdAt
      }
    }
  }

  private func exist(id: UUID) -> Bool {
    guard let modelContext else { return false }
    let descriptor = FetchDescriptor<RunnerModel>(predicate: #Predicate { $0.id == id })
    return ((try? modelContext.fetchCount(descriptor)) ?? 0) > 0
  }

  private func getFrameCount(_ data: Data) -> Int {
    guard let imageSrc = CGImageSourceCreateWithData(data as CFData, nil) else { return 0 }
    return CGImageSourceGetCount(imageSrc)
  }

  public func getRunnerById(_ id: String) -> RunnerModel? {
    return cachedRunners.first { $0.id.uuidString == id }
  }

  public func addRunner(gifData: Data) {
    guard let modelContext else { return }

    let frameCount = getFrameCount(gifData)
    let newRunner = RunnerModel(
      id: UUID(),
      isDefault: false,
      frameNumber: frameCount,
      data: gifData
    )

    modelContext.insert(newRunner)

    do {
      try modelContext.save()
      // 重新获取所有 runner
      let allRunners = try modelContext.fetch(FetchDescriptor<RunnerModel>())
      cachedRunners = sorted(allRunners)

    } catch {
      print("Failed to add custom runner: \(error)")
    }
  }

  public func removeRunner(id: UUID) {
    guard let modelContext else { return }

    do {
      let predicate = #Predicate<RunnerModel> { runner in
        runner.id == id
      }
      let descriptor = FetchDescriptor<RunnerModel>(predicate: predicate)

      if let runnerToDelete = try modelContext.fetch(descriptor).first {
        RunnerModel.clearImageCache(for: runnerToDelete)
        modelContext.delete(runnerToDelete)
        cachedRunners.removeAll(where: { $0.id == id })
        try modelContext.save()
      }
    } catch {
      print("Failed to remove custom runner: \(error)")
    }
  }
}
