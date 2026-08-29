//
//  RunnerModel.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import AppKit
import Foundation

/// A GIF descriptor backed by a file in `RunnerStore`.  The GIF itself is
/// lazily mapped into memory only when an animation frame is requested.
final class RunnerModel: Identifiable, Hashable {
  let id: UUID
  let isDefault: Bool
  let frameNumber: Int
  let createdAt: Date

  var dataFileName: String?
  private var cachedData: Data?

  var data: Data {
    get {
      if let cachedData { return cachedData }
      guard let dataFileName else { return Data() }
      let loaded = RunnerStore.loadMedia(named: dataFileName) ?? Data()
      cachedData = loaded
      return loaded
    }
    set {
      cachedData = newValue
      dataFileName = nil
    }
  }

  init(id: UUID, isDefault: Bool, frameNumber: Int, data: Data, createdAt: Date = Date()) {
    self.id = id
    self.isDefault = isDefault
    self.frameNumber = frameNumber
    self.cachedData = data
    self.createdAt = createdAt
  }

  init(
    id: UUID,
    isDefault: Bool,
    frameNumber: Int,
    dataFileName: String,
    createdAt: Date
  ) {
    self.id = id
    self.isDefault = isDefault
    self.frameNumber = frameNumber
    self.dataFileName = dataFileName
    self.createdAt = createdAt
  }

  static func == (lhs: RunnerModel, rhs: RunnerModel) -> Bool {
    lhs.id == rhs.id
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

// 扩展图片的相关功能
@MainActor
extension RunnerModel {

  static var imgCache = [RunnerModel: [Int: CGImage]]()
  private static var defaultImage = #imageLiteral(resourceName: "default").cgImage(forProposedRect: nil, context: nil, hints: nil)!

  /// CGImage 会被静态字典强引用。切换或删除 Runner 时必须主动释放旧帧，
  /// 否则每次打开设置/切换动画都会把新的帧叠加到进程内存中。
  static func clearImageCache() {
    imgCache.removeAll(keepingCapacity: false)
  }

  static func clearImageCache(for runner: RunnerModel) {
    imgCache.removeValue(forKey: runner)
  }

  // 获取图像选项
  private func getImageOptions() -> [CFString: Any] {
    [
      kCGImageSourceShouldCache: kCFBooleanFalse as Any,
      kCGImageSourceCreateThumbnailWithTransform: kCFBooleanTrue as Any,
      kCGImageSourceCreateThumbnailFromImageAlways: kCFBooleanTrue as Any,
      kCGImageSourceThumbnailMaxPixelSize: 200
    ]
  }

  // 获取CGImageSource
  private func getCGImageSource(_ data: Data?) -> CGImageSource? {
    guard let rawData = data else { return nil }
    return CGImageSourceCreateWithData(rawData as CFData, getImageOptions() as CFDictionary)
  }

  // 按帧获取图像
  func getImage(_ index: Int) -> CGImage {
    var safeIndex = index

    if RunnerModel.imgCache[self] == nil {
      RunnerModel.imgCache[self] = [:]
    }

    let cacheList = RunnerModel.imgCache[self]!
    if cacheList[index] == nil {
      if index >= self.frameNumber || index < 0 {
        safeIndex = 0
      }

      guard let img = getCGImageSource(data),
            let cgImage = CGImageSourceCreateImageAtIndex(img, safeIndex, getImageOptions() as CFDictionary) else {
        return Self.defaultImage
      }
      RunnerModel.imgCache[self]![index] = cgImage
    }

    return RunnerModel.imgCache[self]![index]!
  }
}
