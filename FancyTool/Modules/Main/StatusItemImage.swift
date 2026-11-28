import AppKit
import SwiftUI

@MainActor
final class StatusItemImage {
  static let scale: CGFloat = 2
  private var content: NSImage?
  private var image: NSImage?
  private var lightRenderer: ImageRenderer<AnyView>?
  private var darkRenderer: ImageRenderer<AnyView>?

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
    lightRenderer = nil
    darkRenderer = nil
  }

  static func render(_ content: some View, template: Bool = false) -> NSImage? {
    StatusItemImage().render(content, template: template)
  }

  func render(_ content: some View, template: Bool = false) -> NSImage? {
    func render(_ scheme: ColorScheme, using renderer: inout ImageRenderer<AnyView>?) -> NSImage? {
      let view = AnyView(content
        .environment(\.colorScheme, scheme)
        .environment(\.displayScale, Self.scale)
        .environment(\.layoutDirection, NSApp?.userInterfaceLayoutDirection == .rightToLeft ? .rightToLeft : .leftToRight))
      if let renderer {
        renderer.content = view
      } else {
        renderer = ImageRenderer(content: view)
        renderer?.scale = Self.scale
      }
      guard let renderer, let image = Self.bitmap(renderer: renderer) else { return nil }
      return NSImage(cgImage: image, size: NSSize(width: CGFloat(image.width) / Self.scale,
                                               height: CGFloat(image.height) / Self.scale))
    }
    guard let light = render(.light, using: &lightRenderer) else { return nil }
    if template {
      darkRenderer = nil
      light.isTemplate = true
      return light
    }
    guard let dark = render(.dark, using: &darkRenderer) else { return nil }
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
    return bitmap(renderer: renderer)
  }

  private static func bitmap(renderer: ImageRenderer<some View>) -> CGImage? {
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
