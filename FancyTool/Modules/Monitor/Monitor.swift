import SwiftUI
import AppKit
import Combine

@MainActor
final class Monitor {
  static let shared = Monitor()

  private var panel: StatusItemPanel?
  private var item: NSStatusItem?
  private var statusSubscriptions = Set<AnyCancellable>()
  private var statusSelection: MonitorStatusSelection?
  private var statusReadings: MonitorStatusReadings?
  private let statusImage = StatusItemImage()

  func mount() {
    guard item == nil else { return }
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    item.autosaveName = "FancyTool.Monitor"
    self.item = item
    item.button?.target = AppMenuActions.shared
    item.button?.action = #selector(AppMenuActions.monitorPopover(_:))
    item.button?.imagePosition = .imageOnly
    item.button?.setAccessibilityLabel(String(localized: "Monitor"))
    AppState.shared.objectWillChange.receive(on: DispatchQueue.main)
      .sink { [weak self] in self?.refreshStatus() }
      .store(in: &statusSubscriptions)
    SystemMetrics.shared.$bundle.sink { [weak self] bundle in
      self?.refreshStatus(readings: MonitorStatusSelection().readings(bundle))
    }.store(in: &statusSubscriptions)
    refreshStatus()
  }

  func unmount() {
    panel?.close()
    panel = nil
    SystemMetrics.shared.setMonitorPanelVisible(false)
    statusSubscriptions.removeAll()
    statusSelection = nil
    statusReadings = nil
    statusImage.clear()
    if let item { NSStatusBar.system.removeStatusItem(item) }
    item = nil
  }

  func togglePanel(_ sender: NSStatusBarButton) {
    if panel?.isShown == true {
      panel?.close()
      return
    }
    SystemMetrics.shared.setMonitorPanelVisible(true)
    let panel = StatusItemPanel(size: MonitorPopoverView.panelSize, content: MonitorPopoverView())
    // Discard the hidden chart tree; history belongs to SystemMetrics and is
    // ready when the panel is opened again.
    panel.onClose = { [weak self] in
      self?.panel = nil
      SystemMetrics.shared.setMonitorPanelVisible(false)
    }
    self.panel = panel
    panel.show(relativeTo: sender)
  }

  private func refreshStatus(readings: MonitorStatusReadings? = nil) {
    guard let item, let button = item.button else { return }
    let selection = MonitorStatusSelection()
    let readings = readings ?? selection.readings(SystemMetrics.shared.bundle)
    guard statusSelection != selection || statusReadings != readings else { return }
    if statusSelection != selection
      || statusReadings?.hasSameDisplay(as: readings, networkOnly: selection.layout.isNetworkOnly) != true {
      let content = MonitorStatusView(state: selection, readings: readings)
        .frame(height: MonitorStatusLayout.height)
        .padding(.horizontal, MonitorStatusLayout.horizontalPadding)
      guard let image = statusImage.render(content, template: selection.layout.metricCount > 0 || selection.showNetWork) else { return }
      if item.length != selection.layout.size.width { item.length = selection.layout.size.width }
      statusImage.update(image, on: button)
    }
    statusSelection = selection
    statusReadings = readings
    var values: [String] = []
    for (enabled, name, value) in [
      (selection.showCpu, String(localized: "CPU"), readings.cpu),
      (selection.showMemory, String(localized: "Memory"), readings.memory),
      (selection.showStorage, String(localized: "Storage"), readings.storage),
      (selection.showBattery, String(localized: "Battery"), readings.battery)
    ] where enabled {
      values.append(name + ": " + PercentText.oneDecimal(value))
    }
    if selection.showNetWork {
      values.append("↑ \(MonitorByteFormatter.string(readings.upload))/s  ↓ \(MonitorByteFormatter.string(readings.download))/s")
    }
    let description = values.joined(separator: " · ")
    guard button.toolTip != description else { return }
    button.toolTip = description
    button.setAccessibilityValue(description)
  }
}

private struct MonitorStatusView: View {
  let state: MonitorStatusSelection
  let readings: MonitorStatusReadings

  private var hasMetrics: Bool {
    state.showCpu || state.showNetWork || state.showStorage || state.showMemory || state.showBattery
  }

  var body: some View {
    if hasMetrics {
      MonitorView(state: state, readings: readings)
    } else {
      Image(RunnerConfig.defaultIconName)
        .resizable()
        .interpolation(.none)
        .scaledToFit()
        .frame(width: 25, height: 25)
        .frame(width: MonitorStatusLayout.emptyWidth,
               height: MonitorStatusLayout.height, alignment: .center)
        .clipped()
    }
  }
}
