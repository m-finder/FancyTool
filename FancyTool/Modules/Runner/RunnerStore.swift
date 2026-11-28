import Foundation
import CryptoKit

/// A single FIFO worker owns the manifest and all imports/removals.
final class RunnerStore: @unchecked Sendable {
  typealias Completion = @MainActor @Sendable (Result<[RunnerModel], Error>) -> Void
  private struct Manifest: Codable {
    var version = 1
    var runners: [RunnerModel]
    var defaultCache: [String: DefaultCache]?

    private enum CodingKeys: String, CodingKey { case version, runners, defaultCache }

    init(runners: [RunnerModel], defaultCache: [String: DefaultCache]) {
      self.runners = runners
      self.defaultCache = defaultCache
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      version = try container.decode(Int.self, forKey: .version)
      runners = try container.decode([RunnerModel].self, forKey: .runners)
      defaultCache = try? container.decode([String: DefaultCache].self, forKey: .defaultCache)
    }
  }
  private struct DefaultCache: Codable, Equatable {
    var version = 1
    var sourceDigest: Data
    var mediaDigest: Data
    var outputHeight: Int
    var frames: Int
  }
  private let queue = DispatchQueue(label: "FancyTool.Runner.storage", qos: .utility)
  private var runners: [RunnerModel] = []
  private var defaultCache: [String: DefaultCache] = [:]
  private var loaded = false
  private var preparedDefaults = Set<UUID>()
  private var persistedManifest: Data?
  private var manifestNeedsSave = false
  private var needsFullCleanup = true
  private var pendingMedia = Set<String>()

  func load(selectedID: String? = nil, includeAllDefaults: Bool = false, completion: @escaping Completion) {
    perform(completion: completion) {
      try $0.prepareDefaults(selectedID: selectedID, includeAll: includeAllDefaults)
    }
  }

  func add(url: URL, completion: @escaping Completion) {
    perform(completion: completion) { store in
      let access = url.startAccessingSecurityScopedResource()
      defer { if access { url.stopAccessingSecurityScopedResource() } }
      guard let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
            size <= RunnerGIFProcessor.maximumInputBytes else { throw RunnerGIFProcessor.ImportError.tooLarge }
      let prepared = try RunnerGIFProcessor.prepare(Data(contentsOf: url))
      try store.add(prepared, id: UUID(), isDefault: false)
    }
  }

  func remove(id: UUID, completion: @escaping Completion) {
    perform(completion: completion) { $0.runners.removeAll { $0.id == id && !$0.isDefault } }
  }

  private func perform(completion: @escaping Completion, mutation: @escaping @Sendable (RunnerStore) throws -> Void) {
    queue.async {
      let result: Result<[RunnerModel], Error> = autoreleasepool {
        do {
          try self.loadIfNeeded()
          let previous = self.runners
          let previousCache = self.defaultCache
          let previousPrepared = self.preparedDefaults
          self.pendingMedia.removeAll()
          do {
            try mutation(self)
            self.runners.sort {
              if $0.isDefault != $1.isDefault { return $0.isDefault }
              return $0.isDefault ? $0.id.uuidString < $1.id.uuidString : $0.createdAt < $1.createdAt
            }
            if self.manifestNeedsSave || !Self.sameRecords(self.runners, previous) || self.defaultCache != previousCache {
              let encoder = JSONEncoder()
              encoder.outputFormatting = [.sortedKeys]
              let data = try encoder.encode(Manifest(runners: self.runners, defaultCache: self.defaultCache))
              if data != self.persistedManifest {
                try FancyToolFileStore.writeAtomically(data, to: Self.manifestURL())
                self.persistedManifest = data
              }
              self.manifestNeedsSave = false
            }
          } catch {
            self.runners = previous
            self.defaultCache = previousCache
            self.preparedDefaults = previousPrepared
            for name in self.pendingMedia.subtracting(Set(previous.map(\.dataFileName))) {
              if let url = try? Self.mediaURL(name) { FancyToolFileStore.removeIfExists(url) }
            }
            self.pendingMedia.removeAll()
            throw error
          }
          self.pendingMedia.removeAll()
          let retained = Set(self.runners.map(\.dataFileName))
          for runner in previous where !retained.contains(runner.dataFileName) {
            if let url = try? Self.mediaURL(runner.dataFileName) { FancyToolFileStore.removeIfExists(url) }
          }
          if self.needsFullCleanup { self.cleanup() }
          return .success(self.runners)
        } catch { return .failure(error) }
      }
      DispatchQueue.main.async { completion(result) }
    }
  }

  private func loadIfNeeded() throws {
    guard !loaded else { return }
    let activeDefaultIDs = Set(Self.defaults.values.compactMap(UUID.init(uuidString:)))
    let url = try Self.manifestURL()
    if FileManager.default.fileExists(atPath: url.path) {
      let data = try Data(contentsOf: url)
      let manifest = try JSONDecoder().decode(Manifest.self, from: data)
      persistedManifest = data
      guard manifest.version == 1 else { throw CocoaError(.fileReadCorruptFile) }
      defaultCache = (manifest.defaultCache ?? [:]).filter { key, _ in
        UUID(uuidString: key).map(activeDefaultIDs.contains) ?? false
      }
      runners = manifest.runners.filter {
        guard !$0.isDefault || activeDefaultIDs.contains($0.id) else { return false }
        guard let url = try? Self.mediaURL($0.dataFileName) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
      }
      manifestNeedsSave = !Self.sameRecords(runners, manifest.runners) || defaultCache != manifest.defaultCache
    } else {
      manifestNeedsSave = true
    }
    loaded = true
  }

  private static let defaults = ["1": "10001b46-eb35-4625-bb4a-bc0a25c3310b", "2": "10002b46-eb35-4625-bb4a-bc0a25c3310b",
                    "3": "10003b46-eb35-4625-bb4a-bc0a25c3310b",
                    "4": "10004b46-eb35-4625-bb4a-bc0a25c3310b",
                    "5": "10005b46-eb35-4625-bb4a-bc0a25c3310b",
                    "6": "10006b46-eb35-4625-bb4a-bc0a25c3310b",
                    "7": "10007b46-eb35-4625-bb4a-bc0a25c3310b",
                    "8": "10008b46-eb35-4625-bb4a-bc0a25c3310b",
                    "9": "10009b46-eb35-4625-bb4a-bc0a25c3310b",
                    "10": "10013b46-eb35-4625-bb4a-bc0a25c3310b",
                    "11": "10018b46-eb35-4625-bb4a-bc0a25c3310b",
                    "12": "10024b46-eb35-4625-bb4a-bc0a25c3310b"]

  private func prepareDefaults(selectedID: String?, includeAll: Bool) throws {
    for (resourceName, idString) in Self.defaults {
      guard let id = UUID(uuidString: idString),
            includeAll || id == selectedID.flatMap(UUID.init(uuidString:)),
            !preparedDefaults.contains(id),
            let url = Bundle.main.url(forResource: resourceName, withExtension: "gif") else { continue }
      let existingIndex = runners.firstIndex(where: { $0.id == id })
      if let existingIndex, !runners[existingIndex].isDefault { continue }
      let outputHeight = (Int(resourceName) ?? 0) >= 5 ? 88 : RunnerGIFProcessor.displayHeight
      let sourceData = try Data(contentsOf: url)
      let sourceDigest = Data(SHA256.hash(data: sourceData))
      let mediaData = existingIndex.flatMap { try? Data(contentsOf: Self.mediaURL(runners[$0].dataFileName)) }
      if let existingIndex, let cached = defaultCache[id.uuidString],
         cached.version == 1, cached.outputHeight == outputHeight,
         cached.frames == runners[existingIndex].frameNumber, cached.sourceDigest == sourceDigest,
         let mediaData, cached.mediaDigest == Data(SHA256.hash(data: mediaData)) {
        preparedDefaults.insert(id)
        continue
      }
      let prepared = try RunnerGIFProcessor.prepare(sourceData, outputHeight: outputHeight)
      if let existingIndex, runners[existingIndex].isDefault {
        let existing = runners[existingIndex]
        let mediaURL = try Self.mediaURL(existing.dataFileName)
        if mediaData != prepared.data {
          try FancyToolFileStore.writeAtomically(prepared.data, to: mediaURL)
        }
        runners[existingIndex] = RunnerModel(id: existing.id, isDefault: true, frameNumber: prepared.frames,
                                             dataFileName: existing.dataFileName, createdAt: existing.createdAt)
      } else {
        try add(prepared, id: id, isDefault: true)
      }
      defaultCache[id.uuidString] = DefaultCache(sourceDigest: sourceDigest,
                                                mediaDigest: Data(SHA256.hash(data: prepared.data)),
                                                outputHeight: outputHeight, frames: prepared.frames)
      preparedDefaults.insert(id)
    }
  }

  private func add(_ prepared: (data: Data, frames: Int), id: UUID, isDefault: Bool) throws {
    let name = "\(id).gif"
    pendingMedia.insert(name)
    try FancyToolFileStore.writeAtomically(prepared.data, to: Self.mediaURL(name))
    runners.append(RunnerModel(id: id, isDefault: isDefault, frameNumber: prepared.frames,
                               dataFileName: name, createdAt: Date()))
  }

  private static func sameRecords(_ lhs: [RunnerModel], _ rhs: [RunnerModel]) -> Bool {
    lhs.elementsEqual(rhs) {
      $0.id == $1.id && $0.isDefault == $1.isDefault && $0.frameNumber == $1.frameNumber
        && $0.dataFileName == $1.dataFileName && $0.createdAt == $1.createdAt
    }
  }

  private static func manifestURL() throws -> URL {
    try FancyToolFileStore.directory(named: "Runner").appendingPathComponent("runners.json")
  }

  static func mediaURL(_ name: String) throws -> URL {
    guard !name.isEmpty, name == (name as NSString).lastPathComponent, name != ".." else {
      throw CocoaError(.fileReadInvalidFileName)
    }
    let url = try FancyToolFileStore.directory(named: "Runner").appendingPathComponent("Media", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url.appendingPathComponent(name)
  }

  private func cleanup() {
    let names = Set(runners.map(\.dataFileName))
    guard let directory = try? Self.mediaURL("unused").deletingLastPathComponent(),
          let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
    for file in files where !names.contains(file.lastPathComponent) { FancyToolFileStore.removeIfExists(file) }
    needsFullCleanup = false
  }
}
