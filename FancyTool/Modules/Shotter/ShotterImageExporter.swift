import AppKit
import ImageIO
import UniformTypeIdentifiers

struct ShotterImageExport: @unchecked Sendable {
  let source: CGImage
  let imageSize: NSSize
  let annotations: [ShotterAnnotation]

  func pngData() -> Data? {
    if annotations.isEmpty {
      let data = NSMutableData()
      guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
      CGImageDestinationAddImage(destination, source, nil)
      guard CGImageDestinationFinalize(destination) else { return nil }
      return data as Data
    }
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: source.width, pixelsHigh: source.height,
      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
      colorSpaceName: .deviceRGB, bitmapFormat: [], bytesPerRow: 0, bitsPerPixel: 0),
      let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
    let rect = NSRect(x: 0, y: 0, width: source.width, height: source.height)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .none
    NSImage(cgImage: source, size: rect.size).draw(in: rect, from: .zero, operation: .copy, fraction: 1)
    annotations.forEach { $0.draw(in: rect, imageSize: imageSize) }
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])
  }
}

enum ShotterImageExporter {
  private static let queue = DispatchQueue(label: "com.wu.FancyTool.image-export", qos: .userInitiated,
                                           target: .global(qos: .userInitiated))

  static func export(_ snapshot: ShotterImageExport, to url: URL? = nil) async throws -> Data? {
    try await withCheckedThrowingContinuation { continuation in
      queue.async {
        let result: Result<Data?, Error> = autoreleasepool {
          guard let data = snapshot.pngData() else {
            return .failure(ExportError.encoding)
          }
          guard let url else { return .success(data) }
          do {
            try data.write(to: url, options: .atomic)
            return .success(nil)
          } catch { return .failure(error) }
        }
        continuation.resume(with: result)
      }
    }
  }

  private enum ExportError: LocalizedError {
    case encoding
    var errorDescription: String? { String(localized: "Unable to create PNG data.") }
  }
}
