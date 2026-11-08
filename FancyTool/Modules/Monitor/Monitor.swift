import SwiftUI
import AppKit

@MainActor
final class Monitor {
  static let shared = Monitor()

  private var panel: StatusItemPanel?
  private var item: NSStatusItem?
  private var hosting: HostingView?

  func mount() {
    guard item == nil else { return }
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    self.item = item
    hosting = HostingView(
      view: MonitorStatusView().frame(height: 22).padding(.horizontal, 4),
      item: item,
      target: AppMenuActions.shared,
      action: #selector(AppMenuActions.monitorPopover(_:))
    )
  }

  func unmount() {
    panel?.close()
    panel = nil
    hosting?.unmount()
    hosting = nil
    if let item { NSStatusBar.system.removeStatusItem(item) }
    item = nil
  }

  func togglePanel(_ sender: NSStatusBarButton) {
    if panel?.isShown == true {
      panel?.close()
      return
    }
    let panel = StatusItemPanel(size: MonitorPopoverView.panelSize, content: MonitorPopoverView())
    // Discard the hidden chart tree; history belongs to SystemMetrics and is
    // ready when the panel is opened again.
    panel.onClose = { [weak self] in self?.panel = nil }
    self.panel = panel
    panel.show(relativeTo: sender)
  }
}

private struct MonitorStatusView: View {
  @ObservedObject private var state = AppState.shared

  private var hasMetrics: Bool {
    state.showCpu || state.showNetWork || state.showStorage || state.showMemory || state.showBattery
  }

  var body: some View {
    if hasMetrics {
      MonitorView()
    } else {
      Image(RunnerConfig.defaultIconName)
        .resizable()
        .scaledToFit()
        .frame(width: RunnerConfig.defaultIconSize)
    }
  }
}
