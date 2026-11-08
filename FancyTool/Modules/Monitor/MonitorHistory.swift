import Foundation
import SystemInfoKit

struct MonitorHistory {
  static let sampleInterval: TimeInterval = 5
  static let duration: TimeInterval = 300
  private(set) var samples: [Sample] = []

  enum Metric { case cpu, memory, storage, upload, download }

  struct Sample {
    let date: Date
    let cpu: Double?
    let memory: Double?
    let storage: Double?
    let upload: Double?
    let download: Double?

    func value(for metric: Metric) -> Double? {
      switch metric {
      case .cpu: cpu
      case .memory: memory
      case .storage: storage
      case .upload: upload
      case .download: download
      }
    }
  }

  struct Point: Identifiable {
    var id: Date { date }
    let date: Date
    let value: Double
    let segment: Int
  }

  var domain: ClosedRange<Date> {
    let end = samples.last?.date ?? Date()
    return end.addingTimeInterval(-Self.duration)...end
  }

  mutating func append(_ bundle: SystemInfoBundle, at date: Date = Date()) {
    guard samples.last.map({ date > $0.date }) ?? true else { return }
    func percentage(_ value: Percentage?) -> Double? {
      guard let raw = value?.rawValue, raw.isFinite, (0...1).contains(raw) else { return nil }
      return raw * 100
    }
    func speed(_ value: ByteData?) -> Double? {
      guard let rate = value?.byteCount, rate.isFinite, rate >= 0 else { return nil }
      return rate
    }
    let cpu = bundle.cpuInfo
    let memory = bundle.memoryInfo
    let storage = bundle.storageInfo
    let network = bundle.networkInfo
    // The library's .zero placeholders are not measurements. A genuine idle CPU
    // still has nonzero idle ticks, and real memory/storage have byte counts.
    let cpuReady = cpu.map { $0.system.rawValue + $0.user.rawValue + $0.idle.rawValue > 0 } ?? false
    let memoryReady = memory.map { $0.app.byteCount + $0.wired.byteCount + $0.compressed.byteCount > 0 } ?? false
    let storageReady = (storage?.total.byteCount ?? 0) > 0
    samples.append(Sample(date: date, cpu: cpuReady ? percentage(cpu?.percentage) : nil,
                          memory: memoryReady ? percentage(memory?.percentage) : nil,
                          storage: storageReady ? percentage(storage?.percentage) : nil,
                          upload: network?.hasConnection == true ? speed(network?.upload) : nil,
                          download: network?.hasConnection == true ? speed(network?.download) : nil))
    samples.removeAll { $0.date < date.addingTimeInterval(-Self.duration) }
    let limit = Int(Self.duration / Self.sampleInterval) + 1
    if samples.count > limit { samples.removeFirst(samples.count - limit) }
  }

  func points(for metric: Metric) -> [Point] {
    var result: [Point] = []
    var segment = 0
    var previous: Date?
    for sample in samples {
      guard let value = sample.value(for: metric) else {
        segment += 1
        previous = nil
        continue
      }
      if let previous, sample.date.timeIntervalSince(previous) > Self.sampleInterval * 3 { segment += 1 }
      result.append(Point(date: sample.date, value: value, segment: segment))
      previous = sample.date
    }
    return result
  }
}
