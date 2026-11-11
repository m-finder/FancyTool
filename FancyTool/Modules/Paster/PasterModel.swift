import Foundation

/// Immutable snapshots cross from the serial store to the UI. Media stays on disk.
struct PasterModel: Identifiable, Codable, Sendable, Equatable {
  var id = UUID()
  var content: String?
  var imageFileName: String?
  var thumbnailFileName: String?
  var imageWidth: Double?
  var imageHeight: Double?
  var icon: String
  var createdAt = Date()
  var isPinned = false
  // Optional so version-1 histories remain readable.
  var storedBytes: Int?
  var imageDigest: String?
}

/// Strict byte budget, unlike NSCache's advisory totalCostLimit. Queue-confined.
struct PasterDataCache {
  let capacity: Int
  private var entries: [String: Data] = [:]
  private var order: [String] = []
  private(set) var byteCount = 0

  mutating func value(for key: String) -> Data? {
    guard let value = entries[key] else { return nil }
    order.removeAll { $0 == key }
    order.append(key)
    return value
  }

  mutating func insert(_ data: Data, for key: String) {
    remove(key)
    guard data.count <= capacity else { return }
    while byteCount + data.count > capacity, let oldest = order.first { remove(oldest) }
    entries[key] = data
    order.append(key)
    byteCount += data.count
  }

  mutating func retain(keys: Set<String>) {
    for key in order where !keys.contains(key) { remove(key) }
  }

  private mutating func remove(_ key: String) {
    if let old = entries.removeValue(forKey: key) { byteCount -= old.count }
    order.removeAll { $0 == key }
  }
}
