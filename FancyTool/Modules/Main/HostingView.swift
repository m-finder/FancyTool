import SwiftUI
import AppKit

/// AppKit owns the status item's width; SwiftUI only reports its ideal content.
@MainActor
final class HostingView {
  private let hostingView: StatusButtonHostingView<AnyView>
  private weak var item: NSStatusItem?
  private var resizeWork: DispatchWorkItem?
  private var contentSize = NSSize.zero
  private var fixedSize: NSSize?

  init(view: some View, item: NSStatusItem, target: AnyObject, action: Selector,
       fixedSize: NSSize? = nil) {
    self.item = item
    self.fixedSize = fixedSize
    hostingView = StatusButtonHostingView(rootView: AnyView(EmptyView()))
    hostingView.sizingOptions = fixedSize == nil ? [.intrinsicContentSize] : []
    guard let button = item.button else { return }
    button.target = target
    button.action = action
    button.image = nil
    button.title = ""
    // Keep the content centered while AppKit updates the button asynchronously.
    // Its width comes from SwiftUI's unconstrained layout, never the old button.
    hostingView.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
    if fixedSize != nil {
      // Monitor and Duo already provide fixed geometry. Their value updates
      // must not participate in SwiftUI measurement or queue a resize pass.
      hostingView.rootView = AnyView(view)
    } else {
      hostingView.rootView = AnyView(
        view.fixedSize()
          .onGeometryChange(for: CGSize.self) { $0.size } action: { [weak self] size in
            self?.scheduleResize(to: size)
          }
      )
    }
    button.addSubview(hostingView)
    scheduleResize(to: fixedSize ?? hostingView.intrinsicContentSize)
  }

  func setFixedSize(_ size: NSSize?) {
    guard fixedSize != size else { return }
    fixedSize = size
    hostingView.sizingOptions = size == nil ? [.intrinsicContentSize] : []
    scheduleResize(to: size ?? hostingView.intrinsicContentSize)
  }

  func unmount() {
    resizeWork?.cancel()
    resizeWork = nil
    hostingView.removeFromSuperview()
    item = nil
  }

  private func scheduleResize(to size: NSSize) {
    let nextSize = fixedSize ?? size
    guard nextSize.width.isFinite, nextSize.height.isFinite,
          nextSize.width > 0, nextSize.height > 0 else { return }
    contentSize = nextSize
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
    let frame = NSRect(
      x: button.bounds.midX - length / 2,
      y: button.bounds.midY - contentSize.height / 2,
      width: length,
      height: contentSize.height
    )
    if hostingView.frame != frame { hostingView.frame = frame }
  }
}

/// The status button owns clicks; its SwiftUI content is display-only.
private final class StatusButtonHostingView<Content: View>: NSHostingView<Content> {
  override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
