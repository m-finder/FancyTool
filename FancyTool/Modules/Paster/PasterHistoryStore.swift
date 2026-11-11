import Foundation
import ImageIO
import UniformTypeIdentifiers
import CryptoKit

/// Every read, image conversion, mutation and write runs on this one queue.
/// Only value snapshots leave it; AppKit pasteboard access remains on the main actor.
final class PasterHistoryStore: @unchecked Sendable {
  static let maximumBytes = 256 * 1024 * 1024
  static let cacheBytes = 32 * 1024 * 1024
  typealias Completion = @MainActor @Sendable (Result<[PasterModel], Error>) -> Void

  enum Capture: Sendable {
    case text(String)
    case image(Data)
  }
  private struct Manifest: Codable {
    var version = 1
    var records: [PasterModel]
  }
  private let queue = DispatchQueue(label: "FancyTool.Paster.storage", qos: .utility)
  private let directory: URL?
  private var history: [PasterModel] = []
  private var loaded = false
  private var cache = PasterDataCache(capacity: cacheBytes)

  init(directory: URL? = nil) { self.directory = directory }

  func load(limit: Int, byteLimit: Int = maximumBytes, completion: @escaping Completion) {
    perform(limit: limit, byteLimit: byteLimit, completion: completion) { _ in }
  }

  func capture(_ capture: Capture, icon: String, limit: Int,
               byteLimit: Int = maximumBytes, completion: @escaping Completion) {
    perform(limit: limit, byteLimit: byteLimit, completion: completion) { store in
      var item = PasterModel(icon: icon)
      switch capture {
      case .text(let text):
        guard text.utf8.count <= byteLimit else { return }
        item.content = text
        item.storedBytes = text.utf8.count
      case .image(let data):
        guard data.count <= byteLimit else { return }
        let image = try Self.prepareImage(data)
        let size = image.original.count + image.thumbnail.count
        // An oversized capture must not evict the user's existing history.
        guard size <= byteLimit else { return }
        item.imageDigest = SHA256.hash(data: image.original).map { String(format: "%02x", $0) }.joined()
        item.imageWidth = Double(image.width)
        item.imageHeight = Double(image.height)
        item.storedBytes = size
        if let index = store.history.firstIndex(where: { $0.imageDigest == item.imageDigest }) {
          store.history[index].createdAt = item.createdAt
          return
        }
        item.imageFileName = "\(item.id).image"
        item.thumbnailFileName = "\(item.id).thumbnail"
        try FancyToolFileStore.writeAtomically(image.original, to: store.mediaURL(item.imageFileName!))
        try FancyToolFileStore.writeAtomically(image.thumbnail, to: store.mediaURL(item.thumbnailFileName!))
      }
      if let text = item.content, let index = store.history.firstIndex(where: { $0.content == text }) {
        store.history[index].createdAt = item.createdAt
      } else {
        store.history.append(item)
      }
    }
  }

  func remove(id: UUID, limit: Int, completion: @escaping Completion) {
    perform(limit: limit, completion: completion) { $0.history.removeAll { $0.id == id } }
  }

  func togglePin(id: UUID, limit: Int, completion: @escaping Completion) {
    perform(limit: limit, completion: completion) { store in
      if let index = store.history.firstIndex(where: { $0.id == id }) { store.history[index].isPinned.toggle() }
    }
  }

  func media(named name: String) async -> Data? {
    await withCheckedContinuation { continuation in
      queue.async {
        if let cached = self.cache.value(for: name) { continuation.resume(returning: cached); return }
        let data = try? Data(contentsOf: self.mediaURL(name))
        if let data { self.cache.insert(data, for: name) }
        continuation.resume(returning: data)
      }
    }
  }

  private func perform(limit: Int, byteLimit: Int = maximumBytes, completion: @escaping Completion,
                       mutation: @escaping @Sendable (PasterHistoryStore) throws -> Void) {
    queue.async {
      let result: Result<[PasterModel], Error> = autoreleasepool {
        do {
          try self.loadIfNeeded()
          let previous = self.history
          do {
            try mutation(self)
            self.history = Self.trimmed(self.history, limit: limit, byteLimit: byteLimit)
            let data = try JSONEncoder().encode(Manifest(records: self.history))
            try FancyToolFileStore.writeAtomically(data, to: self.rootURL().appendingPathComponent("history.json"))
          } catch {
            self.history = previous
            throw error
          }
          self.cleanup()
          return .success(self.history)
        } catch { return .failure(error) }
      }
      DispatchQueue.main.async { completion(result) }
    }
  }

  static func trimmed(_ records: [PasterModel], limit: Int, byteLimit: Int) -> [PasterModel] {
    var result = records.sorted {
      if $0.isPinned != $1.isPinned { return $0.isPinned }
      return $0.createdAt > $1.createdAt
    }
    var bytes = result.reduce(0) { $0 + max(0, $1.storedBytes ?? 0) }
    while result.count > max(1, limit) || bytes > max(0, byteLimit) {
      guard let removed = result.popLast() else { break }
      bytes -= max(0, removed.storedBytes ?? 0)
    }
    return result
  }

  private func loadIfNeeded() throws {
    guard !loaded else { return }
    let url = try rootURL().appendingPathComponent("history.json")
    if FileManager.default.fileExists(atPath: url.path) {
      let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: url))
      guard manifest.version == 1 else { throw CocoaError(.fileReadCorruptFile) }
      history = manifest.records
      // Compute actual sizes for old manifests without decoding full images.
      for index in history.indices {
        let item = history[index]
        var bytes = item.content?.utf8.count ?? 0
        for name in [item.imageFileName, item.thumbnailFileName].compactMap({ $0 }) {
          bytes += (try? mediaURL(name).resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        }
        history[index].storedBytes = bytes
        if item.imageDigest == nil, let name = item.imageFileName,
           let data = try? Data(contentsOf: mediaURL(name)) {
          history[index].imageDigest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        }
      }
    }
    loaded = true
  }

  private func rootURL() throws -> URL {
    let url = try directory ?? FancyToolFileStore.directory(named: "Paster")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  private func mediaURL(_ name: String) throws -> URL {
    guard !name.isEmpty, name == (name as NSString).lastPathComponent, name != ".." else {
      throw CocoaError(.fileReadInvalidFileName)
    }
    let url = try rootURL().appendingPathComponent("Media", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url.appendingPathComponent(name)
  }

  private func cleanup() {
    let names = Set(history.flatMap { [$0.imageFileName, $0.thumbnailFileName].compactMap { $0 } })
    cache.retain(keys: names)
    guard let directory = try? rootURL().appendingPathComponent("Media"),
          let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
    for file in files where !names.contains(file.lastPathComponent) { FancyToolFileStore.removeIfExists(file) }
  }

  private static func prepareImage(_ data: Data) throws -> (original: Data, thumbnail: Data, width: Int, height: Int) {
    guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? Int,
          let height = properties[kCGImagePropertyPixelHeight] as? Int,
          width > 0, height > 0, width <= 32_768, height <= 32_768,
          Double(width) * Double(height) <= 100_000_000 else { throw CocoaError(.fileReadCorruptFile) }
    let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 320]
    guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
      throw CocoaError(.fileReadCorruptFile)
    }
    let original: Data
    if CGImageSourceGetType(source) == UTType.png.identifier as CFString {
      original = data
    } else {
      guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw CocoaError(.fileReadCorruptFile) }
      original = try png(image)
    }
    return (original, try png(thumbnail), width, height)
  }

  private static func png(_ image: CGImage) throws -> Data {
    let output = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else {
      throw CocoaError(.fileWriteUnknown)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    return output as Data
  }
}
