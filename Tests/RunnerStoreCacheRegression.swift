import AppKit
import Foundation

enum RunnerPreparationCounter {
  private static let lock = NSLock()
  nonisolated(unsafe) private static var count = 0
  static func record() { lock.withLock { count += 1 } }
  static var value: Int { lock.withLock { count } }
}

enum FancyToolFileStore {
  static let root = URL(fileURLWithPath: ProcessInfo.processInfo.environment["RUNNER_TEST_ROOT"]!)
  private static let lock = NSLock()
  nonisolated(unsafe) private static var writes = 0
  static var mediaWrites: Int { lock.withLock { writes } }

  static func directory(named name: String) throws -> URL {
    let directory = root.appendingPathComponent(name)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  static func writeAtomically(_ data: Data, to url: URL) throws {
    try data.write(to: url, options: .atomic)
    if url.pathExtension == "gif" { lock.withLock { writes += 1 } }
  }

  static func removeIfExists(_ url: URL) { try? FileManager.default.removeItem(at: url) }
}

@main
enum RunnerStoreCacheRegression {
  static func main() async throws {
    let models = try await load("cold", preparations: 12, mediaWrites: 12)
    precondition(models.count == 12 && models.allSatisfy(\.isDefault))
    precondition(models.map(\.frameNumber) == [14, 6, 32, 10, 24, 48, 19, 48, 36, 29, 19, 6])
    let originalMedia = try media(models)
    let originalManifest = try manifest()
    let first = models[0]
    let firstKey = first.id.uuidString
    let firstURL = try RunnerStore.mediaURL(first.dataFileName)
    let resourceURL = Bundle.main.url(forResource: "1", withExtension: "gif")!
    let originalResource = try Data(contentsOf: resourceURL)

    for _ in 0..<3 {
      let cached = try await load("warm", preparations: 0, mediaWrites: 0)
      try unchanged(cached, models: models, media: originalMedia)
    }

    var oldManifest = originalManifest
    oldManifest.removeValue(forKey: "defaultCache")
    try writeManifest(oldManifest)
    let migrated = try await load("legacy manifest", preparations: 12, mediaWrites: 0)
    try unchanged(migrated, models: models, media: originalMedia)
    _ = try await load("migrated warm", preparations: 0, mediaWrites: 0)

    var malformedCache = try manifest()
    malformedCache["defaultCache"] = [firstKey: ["version": "damaged"]]
    try writeManifest(malformedCache)
    let recoveredMetadata = try await load("malformed cache metadata", preparations: 12, mediaWrites: 0)
    try unchanged(recoveredMetadata, models: models, media: originalMedia)

    let resourceAttributes = try FileManager.default.attributesOfItem(atPath: resourceURL.path)
    var replacementResource = try Data(contentsOf: Bundle.main.url(forResource: "2", withExtension: "gif")!)
    replacementResource.append(Data(repeating: 0, count: originalResource.count - replacementResource.count))
    try replacementResource.write(to: resourceURL)
    try FileManager.default.setAttributes([.modificationDate: resourceAttributes[.modificationDate]!], ofItemAtPath: resourceURL.path)
    let refreshed = try await load("changed resource same size and date", preparations: 1, mediaWrites: 1)
    precondition(refreshed[0].frameNumber == models[1].frameNumber)
    precondition(refreshed[0].id == first.id && refreshed[0].createdAt == first.createdAt)
    let changedMedia = try Data(contentsOf: firstURL)
    precondition(changedMedia == originalMedia[models[1].id])
    _ = try await load("changed resource warm", preparations: 0, mediaWrites: 0)
    try originalResource.write(to: resourceURL)
    let restored = try await load("restored resource", preparations: 1, mediaWrites: 1)
    try unchanged(restored, models: models, media: originalMedia)

    let attributes = try FileManager.default.attributesOfItem(atPath: firstURL.path)
    let damaged = Data(repeating: 0, count: originalMedia[first.id]!.count)
    try damaged.write(to: firstURL)
    try FileManager.default.setAttributes([.modificationDate: attributes[.modificationDate]!], ofItemAtPath: firstURL.path)
    let repaired = try await load("corrupt cache same size and date", preparations: 1, mediaWrites: 1)
    try unchanged(repaired, models: models, media: originalMedia)

    try FileManager.default.removeItem(at: firstURL)
    let rebuilt = try await load("missing media", preparations: 1, mediaWrites: 1)
    precondition(rebuilt[0].id == first.id && rebuilt[0].frameNumber == first.frameNumber)
    let rebuiltMedia = try media(rebuilt)
    precondition(rebuiltMedia == originalMedia)

    var missingEntry = try manifest()
    var entries = missingEntry["defaultCache"] as! [String: Any]
    entries.removeValue(forKey: firstKey)
    missingEntry["defaultCache"] = entries
    try writeManifest(missingEntry)
    _ = try await load("missing cache entry", preparations: 1, mediaWrites: 0)

    for (field, value) in [("version", 0), ("outputHeight", 1), ("frames", 1)] {
      var changed = try manifest()
      var entries = changed["defaultCache"] as! [String: Any]
      var entry = entries[firstKey] as! [String: Any]
      entry[field] = value
      entries[firstKey] = entry
      changed["defaultCache"] = entries
      try writeManifest(changed)
      _ = try await load("invalid \(field)", preparations: 1, mediaWrites: 0)
    }

    var frameMetadata = try manifest()
    var records = frameMetadata["runners"] as! [[String: Any]]
    records[0]["frameNumber"] = 1
    frameMetadata["runners"] = records
    try writeManifest(frameMetadata)
    let metadataRepaired = try await load("wrong manifest frame count", preparations: 1, mediaWrites: 0)
    precondition(metadataRepaired[0].frameNumber == first.frameNumber)

    let customStore = RunnerStore()
    let imported: [RunnerModel] = try await withCheckedThrowingContinuation { continuation in
      customStore.add(url: resourceURL) { continuation.resume(with: $0) }
    }
    let custom = imported.first { !$0.isDefault }!
    let importedMedia = try media(imported)
    let customLoaded = try await load("custom media retained", preparations: 0, mediaWrites: 0)
    try unchanged(customLoaded, models: imported, media: importedMedia)
    precondition(customLoaded.contains { $0.id == custom.id && !$0.isDefault })
    print("RunnerStore cache regressions passed")
  }

  private static func load(_ label: String, preparations expectedPreparations: Int,
                           mediaWrites expectedWrites: Int) async throws -> [RunnerModel] {
    let start = ProcessInfo.processInfo.systemUptime
    let before = RunnerPreparationCounter.value
    let writes = FancyToolFileStore.mediaWrites
    let models: [RunnerModel] = try await withCheckedThrowingContinuation { continuation in
      RunnerStore().load { continuation.resume(with: $0) }
    }
    let preparations = RunnerPreparationCounter.value - before
    let mediaWrites = FancyToolFileStore.mediaWrites - writes
    let measurement = "\(label): \(String(format: "%.3f", (ProcessInfo.processInfo.systemUptime - start) * 1000)) ms, prepare=\(preparations), media writes=\(mediaWrites)\n"
    FileHandle.standardOutput.write(Data(measurement.utf8))
    precondition(preparations == expectedPreparations, "\(label): expected \(expectedPreparations) preparations, got \(preparations)")
    precondition(mediaWrites == expectedWrites, "\(label): expected \(expectedWrites) media writes, got \(mediaWrites)")
    return models
  }

  private static func media(_ models: [RunnerModel]) throws -> [UUID: Data] {
    try Dictionary(uniqueKeysWithValues: models.map { ($0.id, try Data(contentsOf: RunnerStore.mediaURL($0.dataFileName))) })
  }

  private static func unchanged(_ current: [RunnerModel], models: [RunnerModel], media expectedMedia: [UUID: Data]) throws {
    precondition(current.map(\.id) == models.map(\.id))
    precondition(current.map(\.frameNumber) == models.map(\.frameNumber))
    precondition(current.map(\.createdAt) == models.map(\.createdAt))
    precondition(current.map(\.dataFileName) == models.map(\.dataFileName))
    let currentMedia = try media(current)
    precondition(currentMedia == expectedMedia)
  }

  private static func manifest() throws -> [String: Any] {
    let url = try FancyToolFileStore.directory(named: "Runner").appendingPathComponent("runners.json")
    return try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
  }

  private static func writeManifest(_ value: [String: Any]) throws {
    let url = try FancyToolFileStore.directory(named: "Runner").appendingPathComponent("runners.json")
    try JSONSerialization.data(withJSONObject: value).write(to: url, options: .atomic)
  }
}
