import Foundation

enum PercentText {
  static func whole(_ value: Double?) -> String {
    format(value, fractionDigits: 0)
  }

  static func oneDecimal(_ value: Double?) -> String {
    format(value, fractionDigits: 1)
  }

  private static func format(_ value: Double?, fractionDigits: Int) -> String {
    guard let value, value.isFinite else { return "—" }
    return (value / 100).formatted(.percent.precision(.fractionLength(fractionDigits)))
  }
}
