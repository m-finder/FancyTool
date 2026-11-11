import AppKit
import ImageIO

struct RunnerModel: Identifiable, Codable, Hashable, Sendable {
  let id: UUID
  let isDefault: Bool
  let frameNumber: Int
  let dataFileName: String
  let createdAt: Date

  static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
  func hash(into hasher: inout Hasher) { hasher.combine(id) }

  func imageSource() -> CGImageSource? {
    guard let url = try? RunnerStore.mediaURL(dataFileName) else { return nil }
    return CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary)
  }

  @MainActor
  func getImage(_ index: Int) -> CGImage {
    let safeIndex = (0..<min(frameNumber, RunnerGIFProcessor.maximumFrames)).contains(index) ? index : 0
    if let source = imageSource(),
       let image = RunnerGIFProcessor.displayFrame(source: source, index: safeIndex, height: RunnerGIFProcessor.displayHeight) {
      return image
    }
    return #imageLiteral(resourceName: "default").cgImage(forProposedRect: nil, context: nil, hints: nil)!
  }
}
