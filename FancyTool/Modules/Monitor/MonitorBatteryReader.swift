import Foundation
import IOKit
import SystemInfoKit

enum MonitorBatteryReader {
  static func snapshot() -> BatteryInfo? {
    let properties = readProperties("AppleSmartBattery")
    guard let installed = properties["BatteryInstalled"] as? NSNumber else { return nil }
    let adapter = properties["AdapterDetails"] as? [String: Any]
    let info = BatteryInfo(
      percentage: .zero, isInstalled: installed.boolValue,
      isCharging: (properties["IsCharging"] as? NSNumber)?.boolValue ?? false,
      adapterName: adapter?["Name"] as? String, maxCapacity: .zero,
      cycleCount: (properties["CycleCount"] as? NSNumber)?.intValue ?? 0,
      temperature: Temperature(value: .nan)
    )
    // Only query the pack when this system moved temperature out of the battery.
    let pack = temperature(properties: properties, packProperties: [:]) == nil
      ? readProperties("AppleSmartBatteryPack") : [:]
    return corrected(info, properties: properties, packProperties: pack)
  }

  static func corrected(_ info: BatteryInfo?) -> BatteryInfo? {
    guard let info, info.isInstalled else { return info }
    return corrected(info, properties: readProperties("AppleSmartBattery"),
                     packProperties: readProperties("AppleSmartBatteryPack"))
  }

  private static func readProperties(_ name: String) -> [String: Any] {
    let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceNameMatching(name))
    guard service != IO_OBJECT_NULL else { return [:] }
    defer { IOObjectRelease(service) }

    var properties: Unmanaged<CFMutableDictionary>?
    guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
          let values = properties?.takeRetainedValue() as? [String: Any] else { return [:] }
    return values
  }

  static func corrected(_ info: BatteryInfo, properties: [String: Any],
                        packProperties: [String: Any] = [:]) -> BatteryInfo {
    let data = properties["BatteryData"] as? [String: Any] ?? [:]
    // Newer systems expose the displayed charge separately and move capacity
    // diagnostics into BatteryData. Missing raw keys must not turn both into 0%.
    let charge = ratio(properties["CurrentCapacity"], properties["MaxCapacity"])
      ?? ratio(properties["AppleRawCurrentCapacity"], properties["AppleRawMaxCapacity"])
    let health = ratio(properties["AppleRawMaxCapacity"], properties["DesignCapacity"])
      ?? ratio(data["NominalChargeCapacity"], properties["DesignCapacity"])
      ?? ratio(data["NominalChargeCapacity"], data["DesignCapacity"])

    return BatteryInfo(
      percentage: Percentage(rawValue: charge ?? info.percentage.rawValue, width: info.percentage.width),
      isInstalled: info.isInstalled,
      isCharging: info.isCharging,
      adapterName: info.adapterName,
      maxCapacity: Percentage(rawValue: health ?? info.maxCapacity.rawValue, width: info.maxCapacity.width),
      cycleCount: info.cycleCount,
      temperature: Temperature(value: temperature(properties: properties, packProperties: packProperties)
        ?? validCelsius(info.temperature.value) ?? .nan)
    )
  }

  static func temperature(properties: [String: Any], packProperties: [String: Any]) -> Double? {
    let data = properties["BatteryData"] as? [String: Any] ?? [:]
    let packData = packProperties["BatteryData"] as? [String: Any] ?? [:]
    // Recent systems move the centidegree-Celsius reading to the battery pack.
    // Read by source, never guess a different unit from the value's magnitude.
    for value in [properties["Temperature"], data["Temperature"], packData["Temperature"]] {
      if let raw = value as? NSNumber, let celsius = validCelsius(raw.doubleValue / 100) {
        return celsius
      }
    }
    return nil
  }

  private static func validCelsius(_ value: Double) -> Double? {
    value.isFinite && value > 0 && value <= 125 ? value : nil
  }

  private static func ratio(_ current: Any?, _ maximum: Any?) -> Double? {
    guard let current = (current as? NSNumber)?.doubleValue,
          let maximum = (maximum as? NSNumber)?.doubleValue,
          current.isFinite, maximum.isFinite, current >= 0, maximum > 0 else { return nil }
    return min(current / maximum, 1)
  }
}
