//
//  RunnerStore.swift
//  FancyTool
//

import Foundation

/// Small JSON manifest plus individual GIF files for Runner.
/// This removes the remaining SwiftData/Core Data access path, so the app can
/// never open the globally shared `Application Support/default.store`.
enum RunnerStore {
  private static let manifestFileName = "runners.json"
  private static let mediaDirectoryName = "Media"

  private struct Manifest: Codable {
    var version: Int
    var runners: [Record]
  }

  private struct Record: Codable {
    var id: UUID
    var isDefault: Bool
    var frameNumber: Int
    var dataFileName: String
    var createdAt: Date
  }

  static func load() -> [RunnerModel] {
    do {
      let url = try manifestURL()
      guard FileManager.default.fileExists(atPath: url.path) else { return [] }

      let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: url))
      guard manifest.version == 1 else {
        print("Unsupported runner format: \(manifest.version)")
        return []
      }

      return manifest.runners.compactMap { record -> RunnerModel? in
        guard mediaExists(named: record.dataFileName) else {
          print("Skipping runner with missing GIF: \(record.id)")
          return nil
        }
        return RunnerModel(
          id: record.id,
          isDefault: record.isDefault,
          frameNumber: record.frameNumber,
          dataFileName: record.dataFileName,
          createdAt: record.createdAt
        )
      }
    } catch {
      print("Failed to load runners: \(error)")
      return []
    }
  }

  static func save(_ runners: [RunnerModel]) throws {
    let mediaURL = try mediaDirectoryURL()
    var referencedFiles = Set<String>()
    var records: [Record] = []

    for runner in runners {
      let fileName = try persistDataIfNeeded(for: runner, in: mediaURL)
      referencedFiles.insert(fileName)
      records.append(
        Record(
          id: runner.id,
          isDefault: runner.isDefault,
          frameNumber: runner.frameNumber,
          dataFileName: fileName,
          createdAt: runner.createdAt
        )
      )
    }

    let manifest = Manifest(version: 1, runners: records)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    try FancyToolFileStore.writeAtomically(try encoder.encode(manifest), to: try manifestURL())
    cleanupUnreferencedMedia(in: mediaURL, referencedFiles: referencedFiles)
  }

  static func loadMedia(named fileName: String) -> Data? {
    do {
      return try Data(
        contentsOf: try mediaDirectoryURL().appendingPathComponent(fileName),
        options: [.mappedIfSafe]
      )
    } catch {
      print("Failed to load runner GIF \(fileName): \(error)")
      return nil
    }
  }

  private static func mediaExists(named fileName: String) -> Bool {
    guard let mediaURL = try? mediaDirectoryURL() else { return false }
    return FileManager.default.fileExists(atPath: mediaURL.appendingPathComponent(fileName).path)
  }

  private static func persistDataIfNeeded(for runner: RunnerModel, in directory: URL) throws -> String {
    let fileName = runner.dataFileName ?? "\(runner.id.uuidString).gif"
    let url = directory.appendingPathComponent(fileName)
    if !FileManager.default.fileExists(atPath: url.path) {
      try FancyToolFileStore.writeAtomically(runner.data, to: url)
    }
    runner.dataFileName = fileName
    return fileName
  }

  private static func manifestURL() throws -> URL {
    try FancyToolFileStore.directory(named: "Runner")
      .appendingPathComponent(manifestFileName)
  }

  private static func mediaDirectoryURL() throws -> URL {
    let directory = try FancyToolFileStore.directory(named: "Runner")
      .appendingPathComponent(mediaDirectoryName, isDirectory: true)
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true,
      attributes: nil
    )
    return directory
  }

  private static func cleanupUnreferencedMedia(in directory: URL, referencedFiles: Set<String>) {
    guard let files = try? FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: nil
    ) else {
      return
    }

    for file in files where !referencedFiles.contains(file.lastPathComponent) {
      FancyToolFileStore.removeIfExists(file)
    }
  }
}
