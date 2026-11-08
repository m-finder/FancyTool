import AppKit
import Combine
import SystemInfoKit

struct SystemMetricsDemand: Equatable {
  var monitor = false
  var companion = false
  var animatedRunner = false
  var suspended = false

  var isActive: Bool { !suspended && (monitor || companion || animatedRunner) }

  var requests: [SystemInfoType: Bool] {
    [.cpu: !suspended && (monitor || companion || animatedRunner),
     .battery: !suspended && (monitor || companion),
     .memory: !suspended && monitor,
     .storage: !suspended && monitor,
     .network: !suspended && monitor]
  }
}

/// Live measurements are separate from preferences, so a sample never refreshes
/// unrelated settings, clipboard cards or signature views.
@MainActor
final class SystemMetrics: ObservableObject {
  static let shared = SystemMetrics()

  @Published var bundle: SystemInfoBundle?
  private(set) var history = MonitorHistory()
  private var demand = SystemMetricsDemand()
  private let observer = SystemInfoObserver.shared
  private var monitoringTask: Task<Void, Never>?
  private var subscriptions = Set<AnyCancellable>()
  private var displaySleeping = false
  private var needsCPUBaseline = true

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

  private func updateDemand() {
    let state = AppState.shared
    let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    let next = SystemMetricsDemand(
      monitor: state.showMonitor,
      companion: state.runnerCompanion && !reduceMotion,
      animatedRunner: !state.runnerCompanion && !state.runnerId.isEmpty && !reduceMotion
        && !ProcessInfo.processInfo.isLowPowerModeEnabled,
      suspended: displaySleeping
    )
    guard next != demand else { return }
    if !demand.isActive && next.isActive { needsCPUBaseline = true }
    demand = next
    observer.toggleActivation(requests: next.requests)
    guard next.isActive, monitoringTask == nil else { return }

    let stream = observer.systemInfoStream()
    observer.startMonitoring(monitorInterval: MonitorHistory.sampleInterval)
    monitoringTask = Task { [weak self] in
      for await snapshot in stream {
        guard !Task.isCancelled else { break }
        self?.receive(snapshot)
      }
    }
  }

  private func receive(_ snapshot: SystemInfoBundle) {
    guard demand.isActive else { return }
    var snapshot = snapshot
    if needsCPUBaseline, snapshot.cpuInfo != nil {
      // Disabling CPU resets the library's cumulative tick counters. Its first
      // reading establishes a baseline, not usage over a measured interval.
      snapshot.cpuInfo = nil
      needsCPUBaseline = false
    }
    if demand.monitor {
      snapshot.batteryInfo = MonitorBatteryReader.corrected(snapshot.batteryInfo)
      history.append(snapshot)
    }
    bundle = snapshot
  }

  func stop() {
    subscriptions.removeAll()
    monitoringTask?.cancel()
    monitoringTask = nil
    // SystemInfoKit owns one process-wide NWPathMonitor. Cancel only at final
    // shutdown; feature toggles disable repositories without cancelling it.
    observer.stopMonitoring()
  }
}
