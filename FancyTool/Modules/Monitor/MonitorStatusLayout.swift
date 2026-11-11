import AppKit

/// Shared, selection-dependent geometry for the monitor status item.
///
/// The status item's width is derived from enabled metric slots only. Live
/// values are rendered inside those slots and can never participate in sizing.
struct MonitorStatusLayout {
  static let horizontalPadding: CGFloat = 1
  static let height: CGFloat = 20
  static let emptyWidth: CGFloat = 26

  enum Density { case regular, balanced, compact }
  let metricCount: Int
  let showsNetwork: Bool
  let compact: Bool

  init(metricCount: Int, showsNetwork: Bool, compact: Bool = true) {
    self.metricCount = min(4, max(0, metricCount))
    self.showsNetwork = showsNetwork
    self.compact = compact
  }

  @MainActor
  init(for state: AppState) {
    self.init(metricCount: [state.showCpu, state.showMemory, state.showStorage, state.showBattery].filter { $0 }.count,
              showsNetwork: state.showNetWork, compact: state.monitorCompactLayout)
  }

  // Keep availability independent of the saved preference so turning the
  // option off does not hide the control needed to turn it back on.
  var supportsCompactLayout: Bool { metricCount + (showsNetwork ? 1 : 0) > 2 }

  var density: Density {
    guard compact && supportsCompactLayout else { return .regular }
    let count = metricCount + (showsNetwork ? 1 : 0)
    return count == 5 ? .compact : .balanced
  }
  var pairsMetrics: Bool { density != .regular }
  var spacing: CGFloat { density == .compact ? 2 : 3 }
  // One type scale per layout, including the two network rows and any
  // unpaired metric. A single enabled module should not become oversized.
  var metricFontSize: CGFloat { density == .compact ? 7.5 : 8.5 }
  var stackedRowHeight: CGFloat { 9 }
  var metricIconSize: CGSize {
    CGSize(width: density == .compact ? 9 : 11, height: density == .compact ? 8 : 9)
  }
  var metricValueWidth: CGFloat { density == .compact ? 23 : 26 }
  var metricInnerSpacing: CGFloat { 1 }
  var metricWidth: CGFloat {
    density == .compact ? 34 : metricIconSize.width + metricInnerSpacing + metricValueWidth
  }
  // An unpaired metric gets its own full-height icon/value column instead of
  // leaving a tiny row floating in half an otherwise empty column.
  var hasStandaloneMetric: Bool { density == .balanced && metricCount % 2 == 1 }
  var standaloneWidth: CGFloat { metricValueWidth }
  var networkFontSize: CGFloat { metricFontSize }
  // Fits the longest compact rate (999T+) at the existing font sizes.
  var networkValueWidth: CGFloat { density == .compact ? 25 : 28 }
  var networkArrowWidth: CGFloat { 5 }
  var networkArrowSize: CGSize { CGSize(width: networkArrowWidth, height: 7) }
  var networkRowWidth: CGFloat { networkArrowWidth + 1 + networkValueWidth }
  var networkLeadingPadding: CGFloat { metricCount > 0 ? 3 : 0 }
  var networkWidth: CGFloat { networkLeadingPadding + networkRowWidth }
  var contentWidth: CGFloat {
    let columns = pairsMetrics ? (metricCount + 1) / 2 : metricCount
    let fullColumns = columns - (hasStandaloneMetric ? 1 : 0)
    let count = columns + (showsNetwork ? 1 : 0)
    return CGFloat(fullColumns) * metricWidth
      + (hasStandaloneMetric ? standaloneWidth : 0)
      + (showsNetwork ? networkWidth : 0)
      + CGFloat(max(0, count - 1)) * spacing
  }

  var size: NSSize {
    let hasMetrics = metricCount > 0 || showsNetwork
    return NSSize(
      width: ceil((hasMetrics ? contentWidth : Self.emptyWidth) + Self.horizontalPadding * 2),
      height: Self.height
    )
  }

  static func size(metricCount: Int, showsNetwork: Bool, compact: Bool = true) -> NSSize {
    Self(metricCount: metricCount, showsNetwork: showsNetwork, compact: compact).size
  }

  @MainActor
  static func size(for state: AppState) -> NSSize {
    Self(for: state).size
  }
}
