import SwiftUI
import AppKit

@MainActor
final class Texter {
  static let shared = Texter()

  private var panel: StatusItemPanel?
  private var item: NSStatusItem?
  private var statusView: TexterStatusView?
  private var textWhenOpened: String?
  private var panelContentHeight: CGFloat?

  func mount() {
    guard item == nil else { return }
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    self.item = item
    item.button?.target = AppMenuActions.shared
    item.button?.action = #selector(AppMenuActions.textPopover(_:))
    statusView = TexterStatusView(item: item)
  }

  func unmount() {
    panel?.close()
    panel = nil
    statusView?.unmount()
    statusView = nil
    if let item { NSStatusBar.system.removeStatusItem(item) }
    item = nil
  }

  func togglePanel(_ sender: NSStatusBarButton) {
    if panel == nil {
      panel = StatusItemPanel(
        size: TexterPopoverView.panelSize,
        content: TexterPopoverView(
          onSubmit: { [weak self] in self?.panel?.close() },
          onHeightChange: { [weak self] height in
            self?.panelContentHeight = height
            self?.panel?.setContentSize(NSSize(width: TexterPopoverView.panelSize.width, height: height))
          }
        ),
        contentPadding: TexterPopoverView.panelPadding,
        resizesContent: true
      )
      if let height = panelContentHeight {
        panel?.setContentSize(NSSize(width: TexterPopoverView.panelSize.width, height: height))
      }
      panel?.onShow = { [weak self] window in
        self?.textWhenOpened = AppState.shared.text
        Self.focusInputAtEnd(in: window)
      }
      panel?.onClose = { [weak self] in
        guard let self, let previous = self.textWhenOpened else { return }
        self.textWhenOpened = nil
        if previous != AppState.shared.text {
          InteractionFeedback.events.send(.signatureChanged)
        }
      }
    }
    panel?.toggle(relativeTo: sender)
  }

  private static func focusInputAtEnd(in window: NSWindow) {
    func input(in view: NSView) -> NSTextField? {
      if let field = view as? NSTextField, field.isEditable { return field }
      return view.subviews.lazy.compactMap { input(in: $0) }.first
    }
    guard let content = window.contentView, let field = input(in: content) else { return }
    // Showing the panel may already have activated the field editor.
    // Avoid reactivating the input context when the field is already editing.
    if field.currentEditor() == nil {
      guard window.makeFirstResponder(field) else { return }
    }
    guard let editor = field.currentEditor() as? NSTextView else { return }
    let caret = NSRange(location: (editor.string as NSString).length, length: 0)
    editor.setSelectedRange(caret)
    editor.scrollRangeToVisible(caret)
  }
}
