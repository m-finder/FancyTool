import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Import once at 2× menu-bar resolution; never retain source-sized frame arrays.
enum RunnerGIFProcessor {
  static let maximumInputBytes = 20 * 1024 * 1024
  static let maximumFrames = 240
  static let maximumDimension = 4096
  static let displayHeight = 44
  static let displayWidth = 132

  enum ImportError: LocalizedError {
    case invalid, tooLarge, tooManyFrames
    var errorDescription: String? {
      switch self {
      case .invalid: String(localized: "This GIF could not be read.")
      case .tooLarge: String(localized: "Use a GIF under 20 MB and 4096 × 4096 pixels.")
      case .tooManyFrames: String(localized: "Use a GIF with 240 frames or fewer.")
      }
    }
  }

  static func prepare(_ data: Data, outputHeight: Int = displayHeight) throws -> (data: Data, frames: Int) {
    guard data.count <= maximumInputBytes else { throw ImportError.tooLarge }
    guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
          CGImageSourceGetType(source) == UTType.gif.identifier as CFString else { throw ImportError.invalid }
    let count = CGImageSourceGetCount(source)
    guard count > 0 else { throw ImportError.invalid }
    guard count <= maximumFrames else { throw ImportError.tooManyFrames }
    let output = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(output, UTType.gif.identifier as CFString, count, nil) else {
      throw ImportError.invalid
    }
    CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary:
      [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
    for index in 0..<count {
      try autoreleasepool {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0 else { throw ImportError.invalid }
        guard width <= maximumDimension, height <= maximumDimension else { throw ImportError.tooLarge }
        let preparedHeight = min(outputHeight, height)
        guard let frame = displayFrame(source: source, index: index, height: preparedHeight,
                                       maximumHeight: outputHeight) else {
          throw ImportError.invalid
        }
        let gif = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] ?? [:]
        CGImageDestinationAddImage(destination, frame, [kCGImagePropertyGIFDictionary: gif] as CFDictionary)
      }
    }
    guard CGImageDestinationFinalize(destination) else { throw ImportError.invalid }
    let data = output as Data
    guard let encoded = CGImageSourceCreateWithData(data as CFData, nil) else { throw ImportError.invalid }
    // ImageIO can coalesce identical consecutive frames during GIF encoding.
    return (data, CGImageSourceGetCount(encoded))
  }

  /// Also bounds legacy GIFs at playback without changing the user's original files.
  static func displayFrame(source: CGImageSource, index: Int, height: Int,
                           maximumHeight: Int = displayHeight, sharp: Bool = false) -> CGImage? {
    let height = min(maximumHeight, max(1, height))
    let maxWidth = height * 3
    let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: maxWidth,
      kCGImageSourceShouldCache: false]
    guard let image = sharp
      ? CGImageSourceCreateImageAtIndex(source, index, [kCGImageSourceShouldCache: false] as CFDictionary)
      : CGImageSourceCreateThumbnailAtIndex(source, index, options as CFDictionary) else { return nil }
    let ratio = Double(image.width) / Double(image.height)
    let width = min(maxWidth, max(1, Int((Double(height) * ratio).rounded())))
    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
      bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    let factor = min(Double(width) / Double(image.width), Double(height) / Double(image.height))
    let w = Double(image.width) * factor, h = Double(image.height) * factor
    context.interpolationQuality = sharp ? .none : .high
    context.draw(image, in: CGRect(x: (Double(width) - w) / 2, y: (Double(height) - h) / 2, width: w, height: h))
    return context.makeImage()
  }
}
