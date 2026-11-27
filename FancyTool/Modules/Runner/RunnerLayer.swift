//
//  RunnerLayer.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/9/7.
//

import SwiftUI

@MainActor
class RunnerLayer {

  public static var shared = RunnerLayer()

  public var layer: CALayer?

  // MARK: - 挂载动画layer
  public func mount(button: NSStatusBarButton, scale: Double) {
    if let layer, let parent = button.layer, layer.superlayer === parent { return }
    unmount()

    let layer = CALayer()
    layer.frame = button.bounds
    layer.contentsGravity = .resizeAspect
    layer.masksToBounds = false
    layer.isOpaque = false
    layer.contentsScale = scale

    button.wantsLayer = true
    button.layer?.addSublayer(layer)
    self.layer = layer
  }

  // MARK: - 卸载动画layer
  public func unmount(){
    guard let layer else { return }
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    layer.removeAllAnimations()
    layer.contents = nil
    layer.removeFromSuperlayer()
    self.layer = nil
    CATransaction.commit()
  }
}
