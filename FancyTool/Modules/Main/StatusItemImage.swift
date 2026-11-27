import AppKit
import SwiftUI

@MainActor
final class StatusItemImage {
  static let scale: CGFloat = 2
  private var content: NSImage?
  private var image: NSImage?

  func update(_ content: NSImage, on button: NSButton) {
    self.content = content
    if let image, image.size == content.size, image.isTemplate == content.isTemplate {
      image.recache()
      button.needsDisplay = true
      return
    }
    let image = NSImage(size: content.size, flipped: false) { [weak self] rect in
      self?.content?.draw(in: rect)
      return true
    }
    image.cacheMode = .never
    image.isTemplate = content.isTemplate
    self.image = image
    button.image = image
  }

  func clear() {
    content = nil
    image = nil
  }

  static func render(_ content: some View, template: Bool = false) -> NSImage? {
    func render(_ scheme: ColorScheme) -> NSImage? {
      guard let image = bitmap(content
        .environment(\.colorScheme, scheme)
        .environment(\.displayScale, scale)
        .environment(\.layoutDirection, NSApp?.userInterfaceLayoutDirection == .rightToLeft ? .rightToLeft : .leftToRight)) else { return nil }
      return NSImage(cgImage: image, size: NSSize(width: CGFloat(image.width) / scale,
                                               height: CGFloat(image.height) / scale))
    }
    guard let light = render(.light) else { return nil }
    if template {
      light.isTemplate = true
      return light
    }
    guard let dark = render(.dark) else { return nil }
    let image = NSImage(size: light.size, flipped: false) { rect in
      let appearance = NSAppearance.currentDrawing()
      let variant = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
      variant.draw(in: rect)
      return true
    }
    image.cacheMode = .never
    return image
  }

  static func bitmap(_ content: some View) -> CGImage? {
    let renderer = ImageRenderer(content: content.environment(\.displayScale, scale))
    renderer.scale = scale
    var image: CGImage?
    renderer.render(rasterizationScale: scale) { size, draw in
      guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0,
            let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(data: nil, width: Int(ceil(size.width * scale)),
                                    height: Int(ceil(size.height * scale)), bitsPerComponent: 8,
                                    bytesPerRow: 0, space: space,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
      context.scaleBy(x: scale, y: scale)
      draw(context)
      image = context.makeImage()
    }
    return image
  }
}
