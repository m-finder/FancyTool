//
//  Handler.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import AppKit

@MainActor
class RunnerHandler: ObservableObject {

  static let shared = RunnerHandler()
  @Published private(set) var cachedRunners: [RunnerModel] = []

  private let defaultRunners: [String: (String, String)] = [
    "1": ("10001b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "2": ("10002b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "3": ("10003b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "4": ("10004b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "5": ("10005b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "6": ("10006b46-eb35-4625-bb4a-bc0a25c3310b", "default"),
    "7": ("10007b46-eb35-4625-bb4a-bc0a25c3310b", "default")
  ]

  private init() {
    reloadCachedRunners()
    seedDefaultRunners()
  }

  private func seedDefaultRunners() {
    guard let urls = Bundle.main.urls(forResourcesWithExtension: "gif", subdirectory: nil) else {
      return
    }

    var updated = cachedRunners
    for url in urls {
      let name = url.deletingPathExtension().lastPathComponent
      guard let conf = defaultRunners[name],
            let id = UUID(uuidString: conf.0),
            !updated.contains(where: { $0.id == id }),
            let data = try? Data(contentsOf: url) else {
        continue
      }

      updated.append(
        RunnerModel(
          id: id,
          isDefault: true,
          frameNumber: getFrameCount(data),
          data: data
        )
      )
    }

    guard updated.count != cachedRunners.count else { return }
    persist(updated, action: "seed default runners")
  }

  private func reloadCachedRunners() {
    cachedRunners = sorted(RunnerStore.load())
  }

  private func persist(_ runners: [RunnerModel], action: String) {
    do {
      try RunnerStore.save(runners)
      cachedRunners = sorted(runners)
    } catch {
      // Normal file-system errors are caught here; no Core Data exception can
      // abort the process in a later fault/save operation.
      print("Failed to \(action): \(error)")
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

  private func getFrameCount(_ data: Data) -> Int {
    guard let imageSrc = CGImageSourceCreateWithData(data as CFData, nil) else { return 0 }
    return CGImageSourceGetCount(imageSrc)
  }

  public func getRunnerById(_ id: String) -> RunnerModel? {
    cachedRunners.first { $0.id.uuidString == id }
  }

  public func addRunner(gifData: Data) {
    let newRunner = RunnerModel(
      id: UUID(),
      isDefault: false,
      frameNumber: getFrameCount(gifData),
      data: gifData
    )
    persist(cachedRunners + [newRunner], action: "add custom runner")
  }

  public func removeRunner(id: UUID) {
    guard let runner = cachedRunners.first(where: { $0.id == id }) else { return }
    let updated = cachedRunners.filter { $0.id != id }

    do {
      try RunnerStore.save(updated)
      RunnerModel.clearImageCache(for: runner)
      cachedRunners = sorted(updated)
    } catch {
      print("Failed to remove custom runner: \(error)")
    }
  }
}
