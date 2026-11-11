import Darwin
import Foundation
import Network
import SystemInfoKit

enum SystemMetricsUpdate: Sendable {
  case sample(SystemInfoBundle)
  case battery(BatteryInfo?)
}

/// All mutable state is confined to `queue`. One tolerant timer gathers a whole
/// snapshot, then delivers it once on main; no per-metric tasks or worker threads.
final class SystemMetricsSampler: @unchecked Sendable {
  // Share the utility worker pool instead of a serial queue's default
  // overcommit target. Disk queries still stay off the UI thread.
  private let queue = DispatchQueue(label: "com.wu.FancyTool.metrics", qos: .utility,
                                   target: .global(qos: .utility))
  private let deliver: @MainActor @Sendable (SystemMetricsUpdate, UInt64) -> Void
  private let batteryChanges: DispatchSourceUserDataAdd
  private var timer: DispatchSourceTimer?
  private var interval: TimeInterval?
  private var requests: [SystemInfoType: Bool] = [:]
  private var generation: UInt64 = 0
  private var cpu = MonitorCPUCounter()
  private var network = MonitorNetworkCounter()
  private var pathMonitor: NWPathMonitor?
  private var connection = false
  private var interface = NetworkInterface.unknown
  private var ipAddress: String?
  private var storage: StorageInfo?
  private var battery: BatteryInfo?
  private var storageReadAt: TimeInterval = -.infinity
  private var batteryReadAt: TimeInterval = -.infinity

  init(deliver: @escaping @MainActor @Sendable (SystemMetricsUpdate, UInt64) -> Void) {
    self.deliver = deliver
    batteryChanges = DispatchSource.makeUserDataAddSource(queue: queue)
    batteryChanges.setEventHandler { [weak self] in self?.readChangedBattery() }
    batteryChanges.resume()
  }

  deinit { batteryChanges.cancel() }

  func configure(_ demand: SystemMetricsDemand, generation: UInt64) {
    queue.async { [self] in
      let next = demand.requests
      if next[.cpu] != requests[.cpu] { cpu = MonitorCPUCounter() }
      if next[.storage] != requests[.storage] { storageReadAt = -.infinity }
      if next[.battery] != requests[.battery] { batteryReadAt = -.infinity }
      requests = next
      self.generation = generation
      configureNetwork(enabled: next[.network] == true)
      let nextInterval: TimeInterval? = !demand.isActive ? nil
        : [.cpu, .memory, .network].contains(where: { next[$0] == true }) ? MonitorHistory.sampleInterval
        : next[.battery] == true ? 30 : 60
      if interval != nextInterval {
        timer?.cancel()
        timer = nil
        interval = nextInterval
        if let nextInterval {
          let source = DispatchSource.makeTimerSource(queue: queue)
          source.schedule(deadline: .now() + nextInterval, repeating: nextInterval,
                          leeway: .milliseconds(Int(min(1, nextInterval * 0.2) * 1000)))
          source.setEventHandler { [weak self] in self?.sample() }
          timer = source
          source.resume()
        }
      }
      if demand.isActive { sample() }
    }
  }

  func batteryChanged() {
    // Merge pending notifications without starting a debounce timer or
    // dispatching a separate work item for every power-source event.
    batteryChanges.add(data: 1)
  }

  private func readChangedBattery() {
    guard requests[.battery] == true else { return }
    let next = MonitorBatteryReader.snapshot()
    batteryReadAt = ProcessInfo.processInfo.systemUptime
    guard !Self.sameBattery(battery, next) else { return }
    battery = next
    publish(.battery(next))
  }

  private static func sameBattery(_ a: BatteryInfo?, _ b: BatteryInfo?) -> Bool {
    func temperature(_ value: BatteryInfo?) -> Double? {
      value.flatMap { $0.temperature.value.isFinite ? $0.temperature.value : nil }
    }
    return a?.isInstalled == b?.isInstalled && a?.isCharging == b?.isCharging
      && a?.percentage.rawValue == b?.percentage.rawValue && a?.adapterName == b?.adapterName
      && a?.maxCapacity.rawValue == b?.maxCapacity.rawValue && a?.cycleCount == b?.cycleCount
      && temperature(a) == temperature(b)
  }

  func stop() {
    configure(SystemMetricsDemand(), generation: 0)
  }

  private func sample() {
    let now = ProcessInfo.processInfo.systemUptime
    var result = SystemInfoBundle()
    if requests[.cpu] == true { result.cpuInfo = cpu.read() }
    if requests[.memory] == true { result.memoryInfo = Self.readMemory() }
    if requests[.storage] == true {
      // Purgeable-capacity queries contact disk services; they do not belong in
      // the five-second CPU/network loop. Cache them for one minute.
      if now - storageReadAt >= 60 {
        storage = Self.readStorage()
        storageReadAt = now
      }
      result.storageInfo = storage
    }
    if requests[.battery] == true {
      if now - batteryReadAt >= 30 {
        battery = MonitorBatteryReader.snapshot()
        batteryReadAt = now
      }
      result.batteryInfo = battery
    }
    if requests[.network] == true {
      let rates = network.update(Self.readTraffic(), at: now)
      result.networkInfo = NetworkInfo(hasConnection: connection, networkInterface: interface,
        ipAddress: ipAddress, upload: ByteData(byteCount: connection ? rates.upload : 0),
        download: ByteData(byteCount: connection ? rates.download : 0))
    }
    publish(.sample(result))
  }

  private func publish(_ update: SystemMetricsUpdate) {
    let version = generation
    DispatchQueue.main.async { [deliver] in deliver(update, version) }
  }

  private func configureNetwork(enabled: Bool) {
    guard enabled != (pathMonitor != nil) else { return }
    network = MonitorNetworkCounter()
    connection = false
    interface = .unknown
    ipAddress = nil
    if !enabled {
      pathMonitor?.cancel()
      pathMonitor = nil
      return
    }
    let monitor = NWPathMonitor()
    monitor.pathUpdateHandler = { [weak self, weak monitor] path in
      guard let self, let monitor, self.pathMonitor === monitor else { return }
      self.network = MonitorNetworkCounter()
      self.connection = path.status == .satisfied
      let primary = path.availableInterfaces.first { path.usesInterfaceType($0.type) }
      self.interface = switch primary?.type {
      case .wifi: .wifi
      case .wiredEthernet: .ethernet
      case .cellular: .cellular
      case .loopback: .loopback
      default: .unknown
      }
      self.ipAddress = primary.flatMap { Self.readIPAddress($0.name) }
    }
    pathMonitor = monitor
    monitor.start(queue: queue)
  }

  private static func readMemory() -> MemoryInfo? {
    var stats = vm_statistics64()
    var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
    let status = withUnsafeMutablePointer(to: &stats) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
      }
    }
    guard status == KERN_SUCCESS else { return nil }
    let page = Double(getpagesize())
    let total = Double(ProcessInfo.processInfo.physicalMemory)
    guard total > 0 else { return nil }
    let app = max(0, Double(stats.active_count) + Double(stats.inactive_count) + Double(stats.speculative_count)
      - Double(stats.purgeable_count) - Double(stats.external_page_count)) * page
    let wired = Double(stats.wire_count) * page
    let compressed = Double(stats.compressor_page_count) * page
    return MemoryInfo(percentage: Percentage(rawValue: min(1, (app + wired + compressed) / total)),
      pressure: Percentage(rawValue: (wired + compressed) / total), app: ByteData(byteCount: app),
      wired: ByteData(byteCount: wired), compressed: ByteData(byteCount: compressed))
  }

  private static func readStorage() -> StorageInfo? {
    guard let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys:
      [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]),
      let totalValue = values.volumeTotalCapacity, totalValue > 0,
      let availableValue = values.volumeAvailableCapacityForImportantUsage else { return nil }
    let total = Double(totalValue)
    let available = min(total, max(0, Double(availableValue)))
    let used = total - available
    return StorageInfo(percentage: Percentage(rawValue: used / total), total: ByteData(byteCount: total),
      available: ByteData(byteCount: available), used: ByteData(byteCount: used))
  }

  private static func readIPAddress(_ name: String) -> String? {
    var addresses: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&addresses) == 0 else { return nil }
    defer { freeifaddrs(addresses) }
    var pointer = addresses
    while let entry = pointer?.pointee {
      pointer = entry.ifa_next
      guard String(cString: entry.ifa_name) == name, let address = entry.ifa_addr,
            address.pointee.sa_family == UInt8(AF_INET) else { continue }
      var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
      if getnameinfo(address, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
        return String(decoding: host.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
      }
    }
    return nil
  }

  private static func readTraffic() -> [UInt16: MonitorNetworkCounter.Bytes]? {
    // IFLIST2 supplies 64-bit counters, avoiding the 4 GB wrap in getifaddrs.
    var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
    var length = 0
    guard sysctl(&mib, u_int(mib.count), nil, &length, nil, 0) == 0, length > 0 else { return nil }
    var data = [UInt8](repeating: 0, count: length)
    let capacity = length
    guard sysctl(&mib, u_int(mib.count), &data, &length, nil, 0) == 0, length <= capacity else { return nil }
    return data.withUnsafeBytes { bytes in
      var result: [UInt16: MonitorNetworkCounter.Bytes] = [:]
      var offset = 0
      while offset + 4 <= length {
        let size = Int(bytes.loadUnaligned(fromByteOffset: offset, as: UInt16.self))
        guard size >= 4, offset + size <= length else { break }
        if bytes[offset + 3] == RTM_IFINFO2, size >= MemoryLayout<if_msghdr2>.size {
          let entry = bytes.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
          if entry.ifm_flags & IFF_UP != 0 {
            result[entry.ifm_index] = .init(upload: entry.ifm_data.ifi_obytes, download: entry.ifm_data.ifi_ibytes)
          }
        }
        offset += size
      }
      return result
    }
  }
}

struct MonitorCPUCounter {
  private var previous: [UInt32]?

  mutating func read() -> CPUInfo? {
    var stats = host_cpu_load_info()
    var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
    let status = withUnsafeMutablePointer(to: &stats) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
      }
    }
    guard status == KERN_SUCCESS else { return nil }
    return update([stats.cpu_ticks.0, stats.cpu_ticks.1, stats.cpu_ticks.2, stats.cpu_ticks.3])
  }

  mutating func update(_ ticks: [UInt32]) -> CPUInfo? {
    guard ticks.count == 4 else { return nil }
    defer { previous = ticks }
    guard let previous else { return nil }
    let delta = zip(ticks, previous).map { Double($0 &- $1) }
    let total = delta.reduce(0, +)
    guard total > 0 else { return nil }
    let user = (delta[0] + delta[3]) / total
    let system = delta[1] / total
    return CPUInfo(percentage: Percentage(rawValue: user + system), system: Percentage(rawValue: system),
      user: Percentage(rawValue: user), idle: Percentage(rawValue: delta[2] / total))
  }
}

struct MonitorNetworkCounter {
  struct Bytes { let upload: UInt64; let download: UInt64 }
  private var previous: [UInt16: Bytes]?
  private var sampledAt: TimeInterval = 0

  mutating func update(_ values: [UInt16: Bytes]?, at now: TimeInterval) -> (upload: Double, download: Double) {
    guard let values, now.isFinite else { return (0, 0) }
    defer { previous = values; sampledAt = now }
    let elapsed = now - sampledAt
    guard let previous, elapsed > 0 else { return (0, 0) }
    var upload = 0.0, download = 0.0
    for (id, value) in values {
      guard let old = previous[id] else { continue }
      // A reconnected/reset interface establishes a fresh baseline.
      if value.upload >= old.upload { upload += Double(value.upload - old.upload) }
      if value.download >= old.download { download += Double(value.download - old.download) }
    }
    return (upload / elapsed, download / elapsed)
  }
}
