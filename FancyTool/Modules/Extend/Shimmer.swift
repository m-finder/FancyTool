//
//  TexterSettingView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2026/7/25.
//

import SwiftUI
import AppKit

private enum ShimmerConst {
  static let duration: TimeInterval = 2.5
  static let delay: TimeInterval = 2.5
  static let bandSize: CGFloat = 0.3
  static let minP = 0.0 - bandSize
  static let maxP = 1.0 + bandSize
  static let tiltFactor: CGFloat = -0.1
}

enum ShimmerColors {
  static let plain: [CGColor] = [
    NSColor.clear.cgColor,
    NSColor.white.withAlphaComponent(0.8).cgColor,
    NSColor.clear.cgColor
  ]
  
  static let rainbowPalette: [NSColor] = [
    NSColor.orange.withAlphaComponent(0.8),
    NSColor.blue.withAlphaComponent(0.8),
    NSColor.green.withAlphaComponent(0.8)
  ]
  static let rainbow: [CGColor] = [NSColor.clear.cgColor] + rainbowPalette.map(\.cgColor) + [NSColor.clear.cgColor]
}

@MainActor
final class ShimmerVisibilityView: NSView {
  var onVisibilityChange: ((Bool) -> Void)?
  private var observers: [(NotificationCenter, NSObjectProtocol)] = []
  private var displaySleeping = false
  private var systemSleeping = false
  private weak var observedWindow: NSWindow?
  private var lastVisibility: Bool?

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    guard observedWindow !== window else { updateVisibility(); return }
    removeObservers()
    observedWindow = window
    if let window {
      for name in [NSWindow.didChangeOcclusionStateNotification,
                   NSWindow.didMiniaturizeNotification, NSWindow.didDeminiaturizeNotification,
                   NSWindow.willCloseNotification] {
        observe(.default, name, object: window)
      }
      let workspace = NSWorkspace.shared.notificationCenter
      for name in [NSWorkspace.screensDidSleepNotification, NSWorkspace.screensDidWakeNotification,
                   NSWorkspace.willSleepNotification, NSWorkspace.didWakeNotification] {
        observe(workspace, name)
      }
    }
    updateVisibility()
  }

  override func viewDidHide() { super.viewDidHide(); updateVisibility() }
  override func viewDidUnhide() { super.viewDidUnhide(); updateVisibility() }

  func dismantle() {
    removeObservers()
    observedWindow = nil
    publishVisibility(false)
    onVisibilityChange = nil
  }

  private func observe(_ center: NotificationCenter, _ name: Notification.Name, object: AnyObject? = nil) {
    let token = center.addObserver(forName: name, object: object, queue: .main) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self else { return }
        switch name {
        case NSWorkspace.screensDidSleepNotification: self.displaySleeping = true
        case NSWorkspace.screensDidWakeNotification: self.displaySleeping = false
        case NSWorkspace.willSleepNotification: self.systemSleeping = true
        case NSWorkspace.didWakeNotification: self.systemSleeping = false
        case NSWindow.willCloseNotification:
          self.publishVisibility(false)
          return
        default: break
        }
        self.updateVisibility()
      }
    }
    observers.append((center, token))
  }

  private func updateVisibility() {
    var ancestor = superview
    var isStatusItem = false
    while let view = ancestor {
      if view is NSStatusBarButton { isStatusItem = true; break }
      ancestor = view.superview
    }
    let visible = window.map { $0.isVisible && (isStatusItem || $0.occlusionState.contains(.visible)) } ?? false
    publishVisibility(visible && !isHiddenOrHasHiddenAncestor && !displaySleeping && !systemSleeping)
  }

  private func publishVisibility(_ visible: Bool) {
    guard lastVisibility != visible else { return }
    lastVisibility = visible
    onVisibilityChange?(visible)
  }

  private func removeObservers() {
    for (center, token) in observers { center.removeObserver(token) }
    observers.removeAll()
  }
}

@MainActor
enum LayerAnimationPlayback {
  static func setPaused(_ paused: Bool, on layer: CALayer) {
    guard (layer.speed == 0) != paused else { return }
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    defer { CATransaction.commit() }
    if paused {
      let time = layer.convertTime(CACurrentMediaTime(), from: nil)
      layer.speed = 0
      layer.timeOffset = time
    } else {
      let time = layer.timeOffset
      layer.speed = 1
      layer.timeOffset = 0
      layer.beginTime = 0
      layer.beginTime = layer.convertTime(CACurrentMediaTime(), from: nil) - time
    }
  }
}

struct ShimmerView: NSViewRepresentable {
  
  let rainbow: Bool
  let bounds: CGSize
  @Environment(\.layoutDirection) private var layoutDirection
  
  static func configureLayer(_ layer: CAGradientLayer, rainbow: Bool, rtl: Bool) {
    let colors = rainbow ? ShimmerColors.rainbow : ShimmerColors.plain
    let locations: [NSNumber] = rainbow ? [0, 0.25, 0.5, 0.75, 1] : [0, 0.5, 1]
    layer.colors = colors
    layer.locations = locations
    applyInitialPoints(layer: layer, rtl: rtl)
  }
  
  func makeNSView(context: Context) -> ShimmerVisibilityView {
    let view = ShimmerVisibilityView(frame: NSRect(origin: .zero, size: bounds))
    view.wantsLayer = true
    view.layer?.backgroundColor = NSColor.clear.cgColor
    
    let gradLayer = CAGradientLayer()
    gradLayer.isOpaque = false
    gradLayer.frame = NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
    gradLayer.opacity = 0
    
    let rtl = layoutDirection == .rightToLeft
    context.coordinator.gradientLayer = gradLayer
    context.coordinator.rtl = rtl
    context.coordinator.rainbow = rainbow
    
    Self.configureLayer(gradLayer, rainbow: rainbow, rtl: rtl)
    view.layer?.addSublayer(gradLayer)
    view.onVisibilityChange = { [coordinator = context.coordinator] in coordinator.setVisible($0) }
    return view
  }
  
  func updateNSView(_ nsView: ShimmerVisibilityView, context: Context) {
    let newRtl = layoutDirection == .rightToLeft
    let rainbowChanged = context.coordinator.rainbow != rainbow
    let boundsChanged = context.coordinator.gradientLayer?.frame.size != bounds
    
    if context.coordinator.rtl != newRtl || rainbowChanged || boundsChanged{
      context.coordinator.rtl = newRtl
      context.coordinator.rainbow = rainbow
      
      guard let layer = context.coordinator.gradientLayer else { return }
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      defer { CATransaction.commit() }
      if boundsChanged {
        layer.frame = NSRect(origin: .zero, size: bounds)
      }
      Self.configureLayer(layer, rainbow: rainbow, rtl: newRtl)
      context.coordinator.reset()
    }
  }

  static func dismantleNSView(_ nsView: ShimmerVisibilityView, coordinator: Coordinator) {
    nsView.dismantle()
    coordinator.stop()
  }
  
  private static func applyInitialPoints(layer: CAGradientLayer, rtl: Bool) {
    let t = ShimmerConst.tiltFactor
    if rtl {
      layer.startPoint = CGPoint(x: ShimmerConst.maxP, y: ShimmerConst.minP * t)
      layer.endPoint   = CGPoint(x: 1, y: 0)
    } else {
      layer.startPoint = CGPoint(x: ShimmerConst.minP, y: ShimmerConst.minP * t)
      layer.endPoint   = CGPoint(x: ShimmerConst.minP, y: ShimmerConst.minP * t)
    }
  }
  
  @MainActor
  class Coordinator{
    weak var gradientLayer: CAGradientLayer?
    var rtl = false
    var rainbow = false
    private var isVisible = false

    func setVisible(_ visible: Bool) {
      guard isVisible != visible else { return }
      isVisible = visible
      guard let layer = gradientLayer else { return }
      if visible, layer.animation(forKey: "shimmerCycleGroup") == nil { beginAnimation() }
      LayerAnimationPlayback.setPaused(!visible, on: layer)
    }
    
    private func beginAnimation() {
      guard let layer = gradientLayer else { return }
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      defer { CATransaction.commit() }
      layer.opacity = 1
      runAnimation(layer: layer)
    }
    
    func reset() {
      stop()
      if isVisible { beginAnimation() }
    }

    func stop() {
      guard let layer = gradientLayer else { return }
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      defer { CATransaction.commit() }
      layer.opacity = 0
      layer.removeAllAnimations()
    }
    
    private func runAnimation(layer: CAGradientLayer) {
      layer.removeAllAnimations()
      
      let t = ShimmerConst.tiltFactor
      let animDuration = ShimmerConst.duration
      let pauseDelay = ShimmerConst.delay
      let totalCycle = animDuration + pauseDelay
      
      let animStart = CABasicAnimation(keyPath: "startPoint")
      let animEnd   = CABasicAnimation(keyPath: "endPoint")
      
      if rtl {
        animStart.fromValue = CGPoint(x: ShimmerConst.maxP, y: ShimmerConst.minP * t)
        animStart.toValue   = CGPoint(x: 0, y: 1 * t)
        
        animEnd.fromValue = CGPoint(x: 1, y: 0)
        animEnd.toValue   = CGPoint(x: ShimmerConst.minP, y: ShimmerConst.maxP * t)
      } else {
        animStart.fromValue = CGPoint(x: ShimmerConst.minP, y: ShimmerConst.minP * t)
        animStart.toValue   = CGPoint(x: 1, y: 1 * t)
        
        animEnd.fromValue = CGPoint(x: 0, y: 0)
        animEnd.toValue   = CGPoint(x: ShimmerConst.maxP, y: ShimmerConst.maxP * t)
      }
      
      [animStart, animEnd].forEach { anim in
        anim.duration = animDuration
        anim.timingFunction = CAMediaTimingFunction(name: .linear)
      }
      
      // 将两个动画打包进分组
      let group = CAAnimationGroup()
      group.animations = [animStart, animEnd]
      group.duration = totalCycle
      group.repeatCount = .infinity
      group.isRemovedOnCompletion = false
      group.beginTime = layer.convertTime(CACurrentMediaTime(), from: nil)
      
      layer.add(group, forKey: "shimmerCycleGroup")
    }
  }
  
  func makeCoordinator() -> Coordinator { Coordinator() }
}

private struct ShimmerModifier: ViewModifier {
  
  let active: Bool
  let rainbow: Bool
  
  func body(content: Content) -> some View {
    Group {
      if active {
        content.overlay(
          GeometryReader { geo in
            ShimmerView(rainbow: rainbow, bounds: geo.size).mask(content)
          }
        )
      } else {
        content
      }
    }
  }
}

public extension View {
  func shimmering(active: Bool = true, rainbow: Bool = false) -> some View {
    modifier(ShimmerModifier(active: active, rainbow: rainbow))
  }
}
