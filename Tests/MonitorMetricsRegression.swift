import AppKit
import Combine
import Foundation
import SystemInfoKit

@MainActor
final class AppState: ObservableObject {
  static let shared = AppState()
  var showMonitor = false
  var showCpu = false
  var showMemory = false
  var showStorage = false
  var showNetWork = false
  var showBattery = false
  var runnerCompanion = false
  var runnerId = ""
}

final class NWPathMonitor {
  struct Path {
    enum Status { case satisfied, unsatisfied }
    struct Interface {
      enum Kind { case wifi, wiredEthernet, cellular, loopback, other }
      let type = Kind.wifi
      let name = "lo0"
    }
    let status = Status.satisfied
    let availableInterfaces = [Interface()]
    func usesInterfaceType(_ type: Interface.Kind) -> Bool { true }
  }
  var pathUpdateHandler: ((Path) -> Void)?
  func start(queue: DispatchQueue) { pathUpdateHandler?(Path()) }
  func cancel() {}
}

private extension SystemMetricsSampler {
  func synchronize() { queue.sync {} }

  func seedNetwork() {
    queue.sync {
      network = MonitorNetworkCounter()
      _ = network.update([1: .init(upload: 1_000, download: 2_000)], at: 100)
      _ = network.update([1: .init(upload: 6_000, download: 12_000)], at: 105)
      latestSample.networkInfo = NetworkInfo(hasConnection: true, networkInterface: .wifi,
        ipAddress: nil, upload: ByteData(byteCount: 1_000), download: ByteData(byteCount: 2_000))
    }
  }

  func pathChanged() {
    queue.sync { pathMonitor?.pathUpdateHandler?(NWPathMonitor.Path()) }
  }

  func nextRate() -> (upload: Double, download: Double)? {
    queue.sync { network.update([1: .init(upload: 11_000, download: 22_000)], at: 110) }
  }

  func memorySample() -> SystemInfoBundle {
    queue.sync {
      sample()
      return latestSample
    }
  }
}

private extension SystemMetrics {
  func apply(_ update: SystemMetricsUpdate, demand: SystemMetricsDemand) {
    self.demand = demand
    receive(update)
  }
}

@main
struct MonitorMetricsRegression {
  static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
  }

  static func counters() {
    var counter = MonitorNetworkCounter()
    let initial: [UInt16: MonitorNetworkCounter.Bytes] = [1: .init(upload: 4_294_966_000, download: 2_000)]
    require(counter.update(initial, at: 100) == nil, "A baseline is not a zero-speed sample")
    let first = counter.update([1: .init(upload: 4_294_971_000, download: 12_000)], at: 105)!
    require(first.upload == 1_000 && first.download == 2_000, "64-bit counters across 4 GB")
    require(counter.update(nil, at: 110) == nil, "Failed reads must not manufacture a zero")
    require(counter.update(initial, at: 104) == nil, "Out-of-order timestamps must not reset the baseline")
    let recovered = counter.update([1: .init(upload: 4_294_981_000, download: 32_000)], at: 115)!
    require(recovered.upload == 1_000 && recovered.download == 2_000, "Recover over the full elapsed interval")
    let newInterface = counter.update([1: .init(upload: 4_294_986_000, download: 42_000),
                                      2: .init(upload: 900_000_000, download: 800_000_000)], at: 120)!
    require(newInterface.upload == 1_000 && newInterface.download == 2_000, "New interfaces need their own baseline")
    let reset = counter.update([1: .init(upload: 100, download: 200),
                               2: .init(upload: 900_005_000, download: 800_010_000)], at: 125)!
    require(reset.upload == 1_000 && reset.download == 2_000, "One reset interface must not erase the others")
    let idle = counter.update([1: .init(upload: 100, download: 200),
                              2: .init(upload: 900_005_000, download: 800_010_000)], at: 130)!
    require(idle.upload == 0 && idle.download == 0, "A real idle interval must still report zero")
    print("PASS network baselines, failed reads, interface changes, and idle intervals")
  }

  @MainActor
  static func main() async throws {
    setbuf(stdout, nil)
    counters()
    var closed = SystemMetricsDemand(monitor: true, network: true)
    require(closed.requests[.memory] == true, "Closed popovers still need memory history")
    var opened = closed
    opened.panel = true
    let model = SystemMetrics()
    var delivered: [SystemMetricsUpdate] = []
    let sampler = SystemMetricsSampler { update, _ in delivered.append(update) }
    defer { sampler.stop() }
    sampler.configure(closed, generation: 1)
    sampler.synchronize()
    sampler.seedNetwork()
    for _ in 0..<12 { sampler.pathChanged() }
    let afterNotifications = sampler.nextRate()
    require(afterNotifications?.upload == 1_000 && afterNotifications?.download == 2_000,
      "Path notifications must not discard traffic between timer ticks")
    print("PASS twelve consecutive path notifications preserve nonzero rates")

    sampler.seedNetwork()
    sampler.configure(opened, generation: 2)
    sampler.synchronize()
    sampler.configure(closed, generation: 3)
    sampler.synchronize()
    let afterPanel = sampler.nextRate()
    require(afterPanel?.upload == 1_000 && afterPanel?.download == 2_000,
      "Opening and closing the popover must not rebase network counters")
    try await Task.sleep(for: .milliseconds(30))
    let refreshes = delivered.compactMap { update -> SystemInfoBundle? in
      if case let .refresh(value) = update { return value }
      return nil
    }
    require(refreshes.count == 2, "Popover changes should refresh values without extra history points")
    require(refreshes.allSatisfy { $0.networkInfo?.download.byteCount == 2_000 },
      "Popover refresh must preserve the current network reading")
    print("PASS opening and closing the popover preserves the last rate and measurement interval")

    for _ in 0..<4 {
      let snapshot = sampler.memorySample()
      require((snapshot.memoryInfo?.app.byteCount ?? 0) > 0, "Real memory sample missing while closed")
      model.apply(.sample(snapshot), demand: closed)
      try await Task.sleep(for: .milliseconds(2))
    }
    let prior = model.history.points(for: .memory)
    require(prior.count == 4 && prior.allSatisfy { $0.value > 0 && $0.value <= 100 },
      "Memory history must accumulate before the popover opens")
    model.apply(.refresh(refreshes[0]), demand: opened)
    model.apply(.refresh(refreshes[1]), demand: closed)
    require(model.history.points(for: .memory).map(\.date) == prior.map(\.date),
      "Popover visibility must not insert or remove history")
    require(model.sampleSequence == 4, "Refreshes must not consume sample sequence numbers")
    closed.suspended = true
    require(!closed.isActive, "Display sleep must still suspend sampling")
    require(!SystemMetricsDemand().isActive, "Disabling monitoring must still stop sampling")
    print("PASS real memory history while closed, visibility changes, and suspension")
  }
}
