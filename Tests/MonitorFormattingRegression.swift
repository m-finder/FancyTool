import Foundation
import SystemInfoKit

@main
struct MonitorFormattingRegression {
  @MainActor
  static func main() {
    var snapshot = SystemInfoBundle()
    snapshot.networkInfo = NetworkInfo(hasConnection: true, networkInterface: .wifi,
      ipAddress: nil, upload: ByteData(byteCount: 1234), download: ByteData(byteCount: 5678))
    func readings(_ snapshot: SystemInfoBundle, cpu: Bool = false, network: Bool = true) -> MonitorStatusReadings {
      MonitorStatusReadings(snapshot, cpu: cpu, memory: false, storage: false, battery: false, network: network)
    }
    let initial = readings(snapshot)
    snapshot.cpuInfo = CPUInfo(percentage: Percentage(rawValue: 0.25),
      system: .zero, user: .zero, idle: .zero)
    precondition(readings(snapshot) == initial, "Hidden metrics refreshed the status item")
    precondition(readings(snapshot, cpu: true).cpu == 25, "Enabling a metric lost its current value")
    snapshot.networkInfo = NetworkInfo(hasConnection: true, networkInterface: .wifi,
      ipAddress: nil, upload: ByteData(byteCount: 1234), download: ByteData(byteCount: 5679))
    precondition(readings(snapshot) != initial, "A changed rate was suppressed")
    precondition(readings(snapshot, network: false).download == nil, "Disabled network retained its reading")
    print("PASS unchanged readings, hidden metrics, changed rates, and selection changes")
    let values: [Double] = [-1, 0, 0.1, 1, 10, 999, 999.49, 999.5, 1000, 1024,
      999_999, 1_000_000, 1_000_000_000, 1e12, 1e15, 1e18, .infinity, .nan]
      + (1...300).map { Double($0) * 12345.6789 }
    precondition(MonitorByteFormatter.string(nil) == "-")
    for value in values {
      let expected = ByteData(byteCount: value).description
      let actual = MonitorByteFormatter.string(value)
      precondition(actual == expected, "\(Locale.current.identifier) \(value): \(actual) != \(expected)")
    }
    let original = MonitorByteFormatter.string(12345)
    _ = MonitorByteFormatter.string(12345, locale: Locale(identifier: "de_DE"))
    precondition(MonitorByteFormatter.string(12345) == original)
    let start = ProcessInfo.processInfo.systemUptime
    var checksum = 0
    for index in 0..<2_000 {
      checksum += ByteData(byteCount: Double(index) * 12345.6789).description.utf8.count
    }
    let baseline = ProcessInfo.processInfo.systemUptime - start
    let optimizedStart = ProcessInfo.processInfo.systemUptime
    var optimizedChecksum = 0
    for index in 0..<2_000 {
      optimizedChecksum += MonitorByteFormatter.string(Double(index) * 12345.6789).utf8.count
    }
    precondition(checksum == optimizedChecksum)
    let optimized = ProcessInfo.processInfo.systemUptime - optimizedStart
    print("PASS \(Locale.current.identifier): \(values.count) rates; 2,000 formats \(baseline)s -> \(optimized)s")
  }
}
