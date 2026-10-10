//
//  PasterHistoryStore.swift
//  FancyTool
//

import Foundation

/// File-backed persistence for paste history.
///
/// SwiftData/Core Data uses Objective-C exceptions for some SQLite failures;
/// those exceptions bypass Swift's `do/catch` and can terminate the process.
/// Paster only needs a small ordered list, so a versioned JSON manifest plus
/// separate image files is both lighter and failure-safe.
enum PasterHistoryStore {
  private static let manifestFileName = "history.json"
  private static let mediaDirectoryName = "Media"

  private struct Manifest: Codable {
    var version: Int
    var records: [Record]
  }

  private struct Record: Codable {
    var id: UUID
    var content: String?
    var imageFileName: String?
    var thumbnailFileName: String?
    var imageWidth: Double?
    var imageHeight: Double?
    var icon: String
    var createdAt: Date
    var isPinned: Bool
  }

  static func load() -> [PasterModel] {
    do {
      let manifestURL = try manifestURL()
      guard FileManager.default.fileExists(atPath: manifestURL.path) else { return [] }

      let data = try Data(contentsOf: manifestURL)
      let manifest = try JSONDecoder().decode(Manifest.self, from: data)
      guard manifest.version == 1 else {
        print("Unsupported paste history format: \(manifest.version)")
        return []
      }

      return manifest.records.map {
        PasterModel(
          id: $0.id,
          content: $0.content,
          imageFileName: $0.imageFileName,
          thumbnailFileName: $0.thumbnailFileName,
          imageWidth: $0.imageWidth,
          imageHeight: $0.imageHeight,
          icon: $0.icon,
          createdAt: $0.createdAt,
          isPinned: $0.isPinned
        )
      }
    } catch {
      // A malformed or interrupted manifest must not stop clipboard capture.
      // Keep the file in place for manual recovery and start with an empty
      // in-memory list instead of deleting user data automatically.
      print("Failed to load paste history: \(error)")
      return []
    }
  }

  static func save(_ history: [PasterModel]) throws {
    let mediaURL = try mediaDirectoryURL()
    var records: [Record] = []
    var referencedFiles = Set<String>()

    for item in history {
      let imageFileName = try persistImageIfNeeded(for: item, in: mediaURL)
      let thumbnailFileName = try persistThumbnailIfNeeded(for: item, in: mediaURL)

      if let imageFileName { referencedFiles.insert(imageFileName) }
      if let thumbnailFileName { referencedFiles.insert(thumbnailFileName) }

      records.append(
        Record(
          id: item.id,
          content: item.content,
          imageFileName: imageFileName,
          thumbnailFileName: thumbnailFileName,
          imageWidth: item.imageWidth,
          imageHeight: item.imageHeight,
          icon: item.icon,
          createdAt: item.createdAt,
          isPinned: item.isPinned
        )
      )
    }

    let manifest = Manifest(version: 1, records: records)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(manifest)
    try FancyToolFileStore.writeAtomically(data, to: try manifestURL())

    // Only delete obsolete media after the new manifest is safely in place.
    // Any cleanup failure merely leaves an orphan file; it never loses a
    // history record or prevents the next clipboard operation.
    cleanupUnreferencedMedia(in: mediaURL, referencedFiles: referencedFiles)
  }

  static func loadMedia(named fileName: String) -> Data? {
    do {
      let url = try mediaDirectoryURL().appendingPathComponent(fileName)
      return try Data(contentsOf: url, options: [.mappedIfSafe])
    } catch {
      print("Failed to load paste media \(fileName): \(error)")
      return nil
    }
  }

  private static func persistImageIfNeeded(for item: PasterModel, in directory: URL) throws -> String? {
    guard let image = item.image else { return nil }

    let fileName = item.imageFileName ?? "\(item.id.uuidString).image"
    let url = directory.appendingPathComponent(fileName)
    if !FileManager.default.fileExists(atPath: url.path) {
      try FancyToolFileStore.writeAtomically(image, to: url)
    }
    item.imageFileName = fileName
    return fileName
  }

  private static func persistThumbnailIfNeeded(for item: PasterModel, in directory: URL) throws -> String? {
    guard let thumbnail = item.thumbnail else { return nil }

    let fileName = item.thumbnailFileName ?? "\(item.id.uuidString).thumbnail"
    let url = directory.appendingPathComponent(fileName)
    if !FileManager.default.fileExists(atPath: url.path) {
      try FancyToolFileStore.writeAtomically(thumbnail, to: url)
    }
    item.thumbnailFileName = fileName
    return fileName
  }

  private static func manifestURL() throws -> URL {
    try FancyToolFileStore.directory(named: "Paster")
      .appendingPathComponent(manifestFileName)
  }

  private static func mediaDirectoryURL() throws -> URL {
    let directory = try FancyToolFileStore.directory(named: "Paster")
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
