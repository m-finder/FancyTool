//
//  RunnerLayer.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/9/7.
//

import SwiftUI

class RunnerLayer {
  
  public static var shared = RunnerLayer()
  
  public var layer: CALayer?
 
  // MARK: - 挂载动画layer
  public func mount(button: NSStatusBarButton, scale: Double) {
    guard button.layer == nil else { return }
    
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
  
  // MARK: - 模拟卸载动画layer
  public func unmount(){
    self.layer?.removeAnimation(forKey: "runner")
    self.layer?.isHidden = true
  }
}
