import SystemInfoKit

struct MonitorStatusReadings: Equatable {
  let cpu: Double?
  let memory: Double?
  let storage: Double?
  let battery: Double?
  let batterySymbol: String
  let upload: Double?
  let download: Double?

  init(_ bundle: SystemInfoBundle?, cpu: Bool, memory: Bool, storage: Bool, battery: Bool, network: Bool) {
    func finite(_ value: Double?) -> Double? {
      value.flatMap { $0.isFinite ? $0 : nil }
    }
    self.cpu = cpu ? finite(bundle?.cpuInfo?.percentage.value) : nil
    self.memory = memory ? finite(bundle?.memoryInfo?.percentage.value) : nil
    self.storage = storage ? finite(bundle?.storageInfo?.percentage.value) : nil
    self.battery = battery ? finite(bundle?.batteryInfo?.percentage.value) : nil
    batterySymbol = battery ? bundle?.batteryInfo?.icon ?? "battery.50percent" : "battery.50percent"
    upload = network ? bundle?.networkInfo?.upload.byteCount : nil
    download = network ? bundle?.networkInfo?.download.byteCount : nil
  }
}
