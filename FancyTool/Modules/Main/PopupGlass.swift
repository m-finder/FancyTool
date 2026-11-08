import AppKit
import SwiftUI

@MainActor
@available(macOS 26.0, *)
enum PopupGlassSurface {
  static func make<Content: View>(content: Content,
                                 frame: NSRect, cornerRadius: CGFloat) -> NSGlassEffectView {
    let host = NSHostingView(rootView: content)
    host.sizingOptions = []
    host.frame = NSRect(origin: .zero, size: frame.size)
    host.autoresizingMask = [.width, .height]

    let glass = NSGlassEffectView(frame: frame)
    // Leave tint, opacity and appearance at their system defaults. An opaque
    // backing over the glass hides its adaptive material and optical edges.
    glass.style = .regular
    glass.cornerRadius = cornerRadius
    glass.autoresizingMask = [.width, .height]
    // Only contentView is guaranteed to render above the native glass effect.
    glass.contentView = host
    return glass
  }
}
