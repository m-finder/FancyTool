import SwiftUI
import AppKit

/// AppKit owns the status item's width; SwiftUI only reports its ideal content.
@MainActor
final class HostingView {
  private let hostingView: StatusButtonHostingView<AnyView>
  private weak var item: NSStatusItem?
  private var resizeWork: DispatchWorkItem?
  private var contentSize = NSSize.zero

  init(view: some View, item: NSStatusItem, target: AnyObject, action: Selector) {
    self.item = item
    hostingView = StatusButtonHostingView(rootView: AnyView(EmptyView()))
    hostingView.sizingOptions = [.intrinsicContentSize]
    guard let button = item.button else { return }
    button.target = target
    button.action = action
    button.image = nil
    button.title = ""
    // Keep the content centered while AppKit updates the button asynchronously.
    // Its width comes from SwiftUI's unconstrained layout, never the old button.
    hostingView.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
    hostingView.rootView = AnyView(
      view.fixedSize()
        .onGeometryChange(for: CGSize.self) { $0.size } action: { [weak self] size in
          self?.scheduleResize(to: size)
        }
    )
    button.addSubview(hostingView)
    scheduleResize(to: hostingView.intrinsicContentSize)
  }

  func unmount() {
    resizeWork?.cancel()
    resizeWork = nil
    hostingView.removeFromSuperview()
    item = nil
  }

  private func scheduleResize(to size: NSSize) {
    guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else { return }
    contentSize = size
    guard resizeWork == nil else { return }
    let work = DispatchWorkItem { [weak self] in
      self?.resizeWork = nil
      self?.resizeToFit()
    }
    resizeWork = work
    DispatchQueue.main.async(execute: work)
  }

  private func resizeToFit() {
    guard let item, let button = item.button else { return }
    let length = ceil(contentSize.width)
    if abs(item.length - length) > 0.5 { item.length = length }
    hostingView.frame = NSRect(
      x: button.bounds.midX - length / 2,
      y: button.bounds.midY - contentSize.height / 2,
      width: length,
      height: contentSize.height
    )
  }
}

/// The status button owns clicks; its SwiftUI content is display-only.
private final class StatusButtonHostingView<Content: View>: NSHostingView<Content> {
  override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
