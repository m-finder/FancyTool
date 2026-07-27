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

private struct ShimmerColors {
  static let plain: [CGColor] = [
    NSColor.clear.cgColor,
    NSColor.white.withAlphaComponent(0.8).cgColor,
    NSColor.clear.cgColor
  ]
  
  static let rainbow: [CGColor] = [
    NSColor.clear.cgColor,
    NSColor.orange.withAlphaComponent(0.8).cgColor,
    NSColor.blue.withAlphaComponent(0.8).cgColor,
    NSColor.green.withAlphaComponent(0.8).cgColor,
    NSColor.clear.cgColor
  ]
}

private struct ShimmerView: NSViewRepresentable {
  
  let rainbow: Bool
  let bounds: CGSize
  @Environment(\.layoutDirection) private var layoutDirection
  
  private func configureLayer(_ layer: CAGradientLayer, rainbow: Bool, rtl: Bool) {
    let colors = rainbow ? ShimmerColors.rainbow : ShimmerColors.plain
    let locations: [NSNumber] = rainbow ? [0, 0.25, 0.5, 0.75, 1] : [0, 0.5, 1]
    layer.colors = colors
    layer.locations = locations
    applyInitialPoints(layer: layer, rtl: rtl)
  }
  
  func makeNSView(context: Context) -> NSView {
    let view = NSView(frame: NSRect(origin: .zero, size: bounds))
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
    
    configureLayer(gradLayer, rainbow: rainbow, rtl: rtl)
    view.layer?.addSublayer(gradLayer)
    context.coordinator.beginDelay()
    return view
  }
  
  func updateNSView(_ nsView: NSView, context: Context) {
    let newRtl = layoutDirection == .rightToLeft
    let rainbowChanged = context.coordinator.rainbow != rainbow
    let boundsChanged = nsView.bounds.size != bounds
    
    if context.coordinator.rtl != newRtl || rainbowChanged || boundsChanged{
      context.coordinator.rtl = newRtl
      context.coordinator.rainbow = rainbow
      
      guard let layer = context.coordinator.gradientLayer else { return }
      if boundsChanged {
        layer.frame = NSRect(origin: .zero, size: bounds)
      }
      configureLayer(layer, rainbow: rainbow, rtl: newRtl)
      context.coordinator.reset()
    }
  }
  
  private func applyInitialPoints(layer: CAGradientLayer, rtl: Bool) {
    let t = ShimmerConst.tiltFactor
    if rtl {
      layer.startPoint = CGPoint(x: ShimmerConst.maxP, y: ShimmerConst.minP * t)
      layer.endPoint   = CGPoint(x: 1, y: 0)
    } else {
      layer.startPoint = CGPoint(x: ShimmerConst.minP, y: ShimmerConst.minP * t)
      //layer.endPoint   = CGPoint(x: 0, y: 0)
      layer.endPoint   = CGPoint(x: ShimmerConst.minP, y: ShimmerConst.minP * t)
    }
  }
  
  class Coordinator{
    weak var gradientLayer: CAGradientLayer?
    var rtl = false
    var rainbow = false
    
    func beginDelay() {
      guard let layer = gradientLayer else { return }
      layer.opacity = 1
      runAnimation(layer: layer)
    }
    
    func reset() {
      guard let layer = gradientLayer else { return }
      layer.opacity = 0
      layer.removeAllAnimations()
      beginDelay()
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
