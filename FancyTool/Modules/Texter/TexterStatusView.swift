import AppKit
import SwiftUI
import Combine

@MainActor
final class TexterStatusView: NSView {
  private weak var item: NSStatusItem?
  private var image: NSImage?
  private let effects = ShimmerVisibilityView()
  private let borderView = NSView()
  private let border = TexterBorderView.Coordinator()
  private let shimmer = ShimmerView.Coordinator()
  private let gradient = CAGradientLayer()
  private let textMask = CALayer()
  private var subscription: AnyCancellable?
  private var accessibilityObserver: NSObjectProtocol?
  private var configuration: Configuration?
  private var visible = false

  private struct Configuration: Equatable {
    let text: String
    let fontFamily: String
    let fontSize: Int
    let colorIndex: Int
    let customColors: Data
    let normalBorder: Bool
    let rainbowBorder: Bool
    let gradientBackground: Bool
    let clockwise: Bool
    let showShimmer: Bool
    let rainbowShimmer: Bool

    @MainActor
    init(_ state: AppState) {
      text = state.text
      fontFamily = state.fontFamily
      fontSize = state.fontSize
      colorIndex = state.colorIndex
      customColors = state.customColorsData
      normalBorder = state.normalBorder
      rainbowBorder = state.rainbowBorder
      gradientBackground = state.gradientBackground
      clockwise = state.borderClockwise
      showShimmer = state.showShimmer
      rainbowShimmer = state.rainbowShimmer
    }
  }

  init(item: NSStatusItem) {
    self.item = item
    super.init(frame: .zero)
    autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
    effects.wantsLayer = true
    borderView.wantsLayer = true
    effects.addSubview(borderView)
    addSubview(effects)
    border.install(in: borderView)
    gradient.mask = textMask
    gradient.opacity = 0
    effects.layer?.addSublayer(gradient)
    shimmer.gradientLayer = gradient
    effects.onVisibilityChange = { [weak self] visible in
      guard let self else { return }
      self.visible = visible
      self.updateVisibility()
    }
    subscription = AppState.shared.objectWillChange.receive(on: DispatchQueue.main)
      .sink { [weak self] in self?.refresh() }
    accessibilityObserver = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.updateBorder() }
    }
    refresh()
    item.button?.addSubview(self)
  }

  required init?(coder: NSCoder) { nil }

  override func hitTest(_ point: NSPoint) -> NSView? { nil }
  override var allowsVibrancy: Bool { false }

  override func draw(_ dirtyRect: NSRect) {
    image?.draw(in: bounds)
  }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    updateBorder()
  }

  func unmount() {
    subscription = nil
    if let accessibilityObserver {
      NSWorkspace.shared.notificationCenter.removeObserver(accessibilityObserver)
    }
    accessibilityObserver = nil
    effects.dismantle()
    shimmer.stop()
    border.stop()
    removeFromSuperview()
    item = nil
  }

  private func refresh() {
    let next = Configuration(AppState.shared)
    guard configuration != next, let item, let button = item.button else { return }
    guard let image = StatusItemImage.render(TexterView(rendersEffects: false).frame(height: 22)) else { return }
    guard let mask = StatusItemImage.bitmap(TexterView(rendersEffects: false, maskOnly: true).frame(height: 22)) else { return }
    configuration = next
    self.image = image
    let width = ceil(image.size.width)
    if item.length != width { item.length = width }
    frame = NSRect(x: button.bounds.midX - width / 2, y: button.bounds.midY - 11, width: width, height: 22)
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    effects.frame = bounds
    borderView.frame = NSRect(x: 0, y: 1, width: width, height: 20)
    gradient.frame = bounds
    textMask.frame = gradient.bounds
    textMask.contentsScale = StatusItemImage.scale
    textMask.contents = mask
    gradient.contentsScale = StatusItemImage.scale
    shimmer.rtl = userInterfaceLayoutDirection == .rightToLeft
    shimmer.rainbow = next.rainbowShimmer
    ShimmerView.configureLayer(gradient, rainbow: next.rainbowShimmer, rtl: shimmer.rtl)
    gradient.isHidden = !next.showShimmer && !next.rainbowShimmer
    shimmer.reset()
    updateBorder()
    updateVisibility()
    CATransaction.commit()
    button.setAccessibilityLabel(next.text)
    needsDisplay = true
  }

  private func updateBorder() {
    guard let configuration else { return }
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    borderView.isHidden = !configuration.normalBorder && !configuration.rainbowBorder
    effectiveAppearance.performAsCurrentDrawingAppearance {
      border.configure(colors: ShimmerColors.rainbowPalette.map { Color(nsColor: $0) },
                       animated: !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
                       rainbow: configuration.rainbowBorder, clockwise: configuration.clockwise,
                       scale: StatusItemImage.scale)
    }
    border.layout(in: borderView.bounds)
    CATransaction.commit()
    updateVisibility()
  }

  private func updateVisibility() {
    guard let configuration else { return }
    shimmer.setVisible(visible && (configuration.showShimmer || configuration.rainbowShimmer))
    border.setVisible(visible && (configuration.normalBorder || configuration.rainbowBorder))
  }
}
