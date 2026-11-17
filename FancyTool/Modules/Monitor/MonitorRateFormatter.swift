import Foundation
import RegexBuilder

@MainActor
enum MonitorByteFormatter {
  private static let measurement = MeasurementFormatter()
  private static let number = NumberFormatter()
  private static var configuredLocale: Locale?
  private static let components = Regex {
    Capture {
      ChoiceOf {
        Regex {
          OneOrMore(.digit)
          ChoiceOf { "."; "," }
          OneOrMore(.digit)
        }
        OneOrMore(.digit)
      }
    }
    Optionally(.whitespace)
    Capture { OneOrMore(.word) }
  }

  static func string(_ bytes: Double?, locale: Locale = .current) -> String {
    guard let bytes else { return "-" }
    if configuredLocale != locale {
      measurement.locale = locale
      measurement.unitStyle = .short
      measurement.unitOptions = .naturalScale
      number.locale = locale
      number.numberStyle = .decimal
      configuredLocale = locale
    }
    let text = measurement.string(from: Measurement<UnitInformationStorage>(value: bytes, unit: .bytes))
    let match = text.firstMatch(of: components)
    let value = match.flatMap { number.number(from: String($0.1))?.doubleValue }
    return String(format: "%4.1f %@", locale: locale,
      value ?? 0, value != nil ? String(match!.2) : "")
  }
}

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
