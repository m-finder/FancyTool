//
//  FancyToolFileStore.swift
//  FancyTool
//
//  Lightweight, app-scoped file storage used instead of SwiftData's generic default.store.
//

import Foundation

/// All persistent files live below an app-specific directory.  Never use
/// SwiftData's default `Application Support/default.store`: that filename is
/// shared by unrelated applications and was the direct cause of the SQLite
/// collision seen in crash reports.
enum FancyToolFileStore {
  private static let directoryName = "FancyToolData"

  static func rootDirectory() throws -> URL {
    guard let applicationSupport = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first else {
      throw CocoaError(.fileNoSuchFile)
    }

    // Debug and Release have different bundle IDs, so they intentionally do
    // not open or mutate each other's local data while developing.
    let bundleID = Bundle.main.bundleIdentifier ?? "com.wu.FancyTool"
    let root = applicationSupport
      .appendingPathComponent(bundleID, isDirectory: true)
      .appendingPathComponent(directoryName, isDirectory: true)

    try FileManager.default.createDirectory(
      at: root,
      withIntermediateDirectories: true,
      attributes: nil
    )
    return root
  }

  static func directory(named name: String) throws -> URL {
    let directory = try rootDirectory().appendingPathComponent(name, isDirectory: true)
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true,
      attributes: nil
    )
    return directory
  }

  static func writeAtomically(_ data: Data, to url: URL) throws {
    try data.write(to: url, options: .atomic)
  }

  static func removeIfExists(_ url: URL) {
    guard FileManager.default.fileExists(atPath: url.path) else { return }
    try? FileManager.default.removeItem(at: url)
  }
}
