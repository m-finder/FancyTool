import Foundation

enum MonitorRateFormatter {
  /// B/K/M/G/T denote bytes per second in the menu bar; full values stay in the panel.
  static func compact(_ bytes: Double?) -> String {
    guard let bytes, bytes.isFinite, bytes >= 0 else { return "—" }
    let units = ["B", "K", "M", "G", "T"]
    var value = bytes
    var unit = 0
    while value >= 999.5, unit < units.count - 1 {
      value /= 1000
      unit += 1
    }
    if unit == units.count - 1, value > 999 { return "999T+" }
    let number = value < 9.95 && unit > 0
      ? String(format: "%.1f", value)
      : String(format: "%.0f", value)
    return number + units[unit]
  }
}
