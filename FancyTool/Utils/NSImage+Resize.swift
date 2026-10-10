//
//  ColorModel.swift
//  M-Tools
//
//  Created by 吴雲放 on 2026/8/19.
//

import AppKit

extension NSImage {
  func resized(to size: CGFloat) -> NSImage {
    let newImage = NSImage(size: NSSize(width: size, height: size))
    newImage.lockFocus()
    draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    newImage.unlockFocus()
    return newImage
  }

  func thumbnailData(maxDimension: CGFloat) -> (data: Data, size: CGSize)? {
    let originalSize = size
    guard originalSize.width > 0, originalSize.height > 0 else { return nil }

    let scale = min(1, maxDimension / max(originalSize.width, originalSize.height))
    let targetSize = CGSize(
      width: max(1, originalSize.width * scale),
      height: max(1, originalSize.height * scale)
    )

    guard let rep = NSBitmapImageRep(
      bitmapDataPlanes: nil,
      pixelsWide: Int(targetSize.width),
      pixelsHigh: Int(targetSize.height),
      bitsPerSample: 8,
      samplesPerPixel: 4,
      hasAlpha: true,
      isPlanar: false,
      colorSpaceName: .deviceRGB,
      bytesPerRow: 0,
      bitsPerPixel: 0
    ) else {
      return nil
    }

    rep.size = targetSize
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw(
      in: NSRect(origin: .zero, size: targetSize),
      from: NSRect(origin: .zero, size: originalSize),
      operation: .copy,
      fraction: 1
    )
    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else { return nil }
    return (data, targetSize)
  }
}
