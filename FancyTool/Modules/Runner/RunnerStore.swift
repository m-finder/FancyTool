import Foundation

/// A single FIFO worker owns the manifest and all imports/removals.
final class RunnerStore: @unchecked Sendable {
  typealias Completion = @MainActor @Sendable (Result<[RunnerModel], Error>) -> Void
  private struct Manifest: Codable {
    var version = 1
    var runners: [RunnerModel]
  }
  private let queue = DispatchQueue(label: "FancyTool.Runner.storage", qos: .utility)
  private var runners: [RunnerModel] = []
  private var loaded = false

  func load(completion: @escaping Completion) { perform(completion: completion) { _ in } }

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
          do {
            try mutation(self)
            self.runners.sort {
              if $0.isDefault != $1.isDefault { return $0.isDefault }
              return $0.isDefault ? $0.id.uuidString < $1.id.uuidString : $0.createdAt < $1.createdAt
            }
            let data = try JSONEncoder().encode(Manifest(runners: self.runners))
            try FancyToolFileStore.writeAtomically(data, to: Self.manifestURL())
          } catch { self.runners = previous; throw error }
          self.cleanup()
          return .success(self.runners)
        } catch { return .failure(error) }
      }
      DispatchQueue.main.async { completion(result) }
    }
  }

  private func loadIfNeeded() throws {
    guard !loaded else { return }
    let url = try Self.manifestURL()
    if FileManager.default.fileExists(atPath: url.path) {
      let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: url))
      guard manifest.version == 1 else { throw CocoaError(.fileReadCorruptFile) }
      runners = manifest.runners.filter {
        guard let url = try? Self.mediaURL($0.dataFileName) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
      }
    }
    let defaults = ["1": "10001b46-eb35-4625-bb4a-bc0a25c3310b", "2": "10002b46-eb35-4625-bb4a-bc0a25c3310b",
                    "3": "10003b46-eb35-4625-bb4a-bc0a25c3310b"]
    for url in Bundle.main.urls(forResourcesWithExtension: "gif", subdirectory: nil) ?? [] {
      guard let idString = defaults[url.deletingPathExtension().lastPathComponent], let id = UUID(uuidString: idString),
            !runners.contains(where: { $0.id == id }) else { continue }
      let prepared = try RunnerGIFProcessor.prepare(Data(contentsOf: url))
      try add(prepared, id: id, isDefault: true)
    }
    loaded = true
  }

  private func add(_ prepared: (data: Data, frames: Int), id: UUID, isDefault: Bool) throws {
    let name = "\(id).gif"
    try FancyToolFileStore.writeAtomically(prepared.data, to: Self.mediaURL(name))
    runners.append(RunnerModel(id: id, isDefault: isDefault, frameNumber: prepared.frames,
                               dataFileName: name, createdAt: Date()))
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
  }
}
