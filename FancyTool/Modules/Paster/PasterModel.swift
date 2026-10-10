//
//  PasterModel.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/26.
//

import AppKit
import Foundation

/// A lightweight in-memory view model. Image bytes are stored as individual
/// files by `PasterHistoryStore`, and are loaded only when a view or paste
/// operation asks for them.
final class PasterModel: Identifiable, Equatable {
  let id: UUID
  var content: String?
  var imageWidth: Double?
  var imageHeight: Double?
  var icon: String
  var createdAt: Date
  var isPinned: Bool

  var imageFileName: String?
  var thumbnailFileName: String?
  private var cachedImage: Data?
  private var cachedThumbnail: Data?

  var image: Data? {
    get {
      if let cachedImage { return cachedImage }
      guard let imageFileName else { return nil }
      let data = PasterHistoryStore.loadMedia(named: imageFileName)
      cachedImage = data
      return data
    }
    set {
      cachedImage = newValue
      if newValue == nil {
        imageFileName = nil
      }
    }
  }

  var thumbnail: Data? {
    get {
      if let cachedThumbnail { return cachedThumbnail }
      guard let thumbnailFileName else { return nil }
      let data = PasterHistoryStore.loadMedia(named: thumbnailFileName)
      cachedThumbnail = data
      return data
    }
    set {
      cachedThumbnail = newValue
      if newValue == nil {
        thumbnailFileName = nil
      }
    }
  }

  init(content: String, icon: String) {
    self.id = UUID()
    self.content = content
    self.icon = icon
    self.createdAt = Date()
    self.isPinned = false
  }

  init(image: Data, icon: String) {
    self.id = UUID()
    self.icon = icon
    self.createdAt = Date()
    self.isPinned = false
    self.cachedImage = image

    if let nsImage = NSImage(data: image) {
      self.imageWidth = Double(nsImage.size.width)
      self.imageHeight = Double(nsImage.size.height)
      self.cachedThumbnail = nsImage.thumbnailData(maxDimension: 320)?.data
    }
  }

  init(
    id: UUID,
    content: String?,
    imageFileName: String?,
    thumbnailFileName: String?,
    imageWidth: Double?,
    imageHeight: Double?,
    icon: String,
    createdAt: Date,
    isPinned: Bool
  ) {
    self.id = id
    self.content = content
    self.imageFileName = imageFileName
    self.thumbnailFileName = thumbnailFileName
    self.imageWidth = imageWidth
    self.imageHeight = imageHeight
    self.icon = icon
    self.createdAt = createdAt
    self.isPinned = isPinned
  }

  static func == (lhs: PasterModel, rhs: PasterModel) -> Bool {
    if let lhsText = lhs.content, let rhsText = rhs.content {
      return lhsText == rhsText
    }

    if let lhsThumbnail = lhs.thumbnail, let rhsThumbnail = rhs.thumbnail {
      return lhsThumbnail == rhsThumbnail &&
        lhs.imageWidth == rhs.imageWidth &&
        lhs.imageHeight == rhs.imageHeight
    }

    return false
  }
}
