import AppKit
import Combine
import IOKit.ps
import SystemInfoKit

struct SystemMetricsDemand: Equatable, Sendable {
  var monitor = false
  var panel = false
  var cpu = false
  var memory = false
  var storage = false
  var network = false
  var battery = false
  var companion = false
  var animatedRunner = false
  var suspended = false

  var isActive: Bool { requests.values.contains(true) }

  var requests: [SystemInfoType: Bool] {
    [.cpu: !suspended && ((monitor && (cpu || panel)) || companion || animatedRunner),
     .battery: !suspended && ((monitor && (battery || panel)) || companion),
     .memory: !suspended && monitor && (memory || panel),
     .storage: !suspended && monitor && (storage || panel),
     .network: !suspended && monitor && (network || panel)]
  }
}

/// Live measurements are separate from preferences, so a sample never refreshes
/// unrelated settings, clipboard cards or signature views.
@MainActor
final class SystemMetrics: ObservableObject {
  static let shared = SystemMetrics()

  @Published var bundle: SystemInfoBundle?
  private(set) var history = MonitorHistory()
  private(set) var sampleSequence: UInt64 = 0
  private var demand = SystemMetricsDemand()
  private var sampler: SystemMetricsSampler?
  private var generation: UInt64 = 0
  private var powerSource: CFRunLoopSource?
  private var subscriptions = Set<AnyCancellable>()
  private var displaySleeping = false
  private var monitorPanelVisible = false

  func start() {
    guard subscriptions.isEmpty else { return }
    AppState.shared.objectWillChange
      .receive(on: DispatchQueue.main)
      .sink { [weak self] in self?.updateDemand() }
      .store(in: &subscriptions)

    let workspace = NSWorkspace.shared.notificationCenter
    for (name, sleeping) in [(NSWorkspace.screensDidSleepNotification, true),
                             (NSWorkspace.screensDidWakeNotification, false)] {
      workspace.publisher(for: name)
        .sink { [weak self] _ in
          self?.displaySleeping = sleeping
          self?.updateDemand()
        }
        .store(in: &subscriptions)
    }
    workspace.publisher(for: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification)
      .merge(with: NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange))
      .sink { [weak self] _ in self?.updateDemand() }
      .store(in: &subscriptions)
    updateDemand()
  }

  func setMonitorPanelVisible(_ visible: Bool) {
    guard monitorPanelVisible != visible else { return }
    monitorPanelVisible = visible
    updateDemand()
  }

  private func updateDemand() {
    let state = AppState.shared
    let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    let next = SystemMetricsDemand(
      monitor: state.showMonitor, panel: monitorPanelVisible,
      cpu: state.showCpu, memory: state.showMemory, storage: state.showStorage,
      network: state.showNetWork, battery: state.showBattery,
      companion: state.runnerCompanion && !reduceMotion,
      animatedRunner: !state.runnerCompanion && !state.runnerId.isEmpty && !reduceMotion
        && !ProcessInfo.processInfo.isLowPowerModeEnabled,
      suspended: displaySleeping
    )
    guard next != demand else { return }
    let previousRequests = demand.requests
    demand = next
    // Opening a panel or changing a consumer need not restart sampling when
    // the same measurements are already being collected.
    guard next.requests != previousRequests else { return }
    generation &+= 1
    observePowerChanges(next.requests[.battery] == true)
    if !next.isActive {
      sampler?.stop()
      sampler = nil
      return
    }
    if sampler == nil {
      sampler = SystemMetricsSampler { [weak self] update, generation in
        guard let self, self.generation == generation else { return }
        self.receive(update)
      }
    }
    sampler?.configure(next, generation: generation)
  }

  private func observePowerChanges(_ enabled: Bool) {
    guard enabled != (powerSource != nil) else { return }
    if !enabled {
      if let powerSource { CFRunLoopSourceInvalidate(powerSource) }
      powerSource = nil
      return
    }
    powerSource = IOPSNotificationCreateRunLoopSource({ context in
      guard let context else { return }
      MainActor.assumeIsolated {
        Unmanaged<SystemMetrics>.fromOpaque(context).takeUnretainedValue().sampler?.batteryChanged()
      }
    }, Unmanaged.passUnretained(self).toOpaque())?.takeRetainedValue()
    if let powerSource { CFRunLoopAddSource(CFRunLoopGetMain(), powerSource, .commonModes) }
  }

  private func receive(_ update: SystemMetricsUpdate) {
    guard demand.isActive else { return }
    switch update {
    case .sample(let snapshot):
      if demand.monitor { history.append(snapshot) }
      sampleSequence &+= 1
      bundle = snapshot
    case .battery(let battery):
      // Power notifications must not resample CPU/network, add extra chart
      // points, or shorten the network counter's measurement interval.
      guard demand.requests[.battery] == true, var snapshot = bundle else { return }
      snapshot.batteryInfo = battery
      bundle = snapshot
    }
  }

  func stop() {
    subscriptions.removeAll()
    if let powerSource { CFRunLoopSourceInvalidate(powerSource) }
    powerSource = nil
    generation &+= 1
    demand = SystemMetricsDemand()
    sampler?.stop()
    sampler = nil
  }
}
