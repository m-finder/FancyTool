//
//  RounderView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/19.
//

import SwiftUI

class RounderView: NSView {
  
  public var radius: CGFloat {
    didSet {
      guard radius != oldValue else { return }
      updateCornerPath()
      layer?.setNeedsDisplay()
    }
  }
  
  private let cornerPosition: Rounder.CornerPosition
  private var cornerPath: NSBezierPath?
  
  init(
    frame frameRect: NSRect,
    radius: CGFloat,
    cornerPosition: Rounder.CornerPosition
  ) {
    self.radius = radius
    self.cornerPosition = cornerPosition
    super.init(frame: frameRect)
    commonInit()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func commonInit() {
    // 图层配置（关键优化）
    wantsLayer = true
    layer?.masksToBounds = false
    layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 1.0
    layer?.backgroundColor = NSColor.clear.cgColor
    // 禁用隐式动画
    layer?.actions = [
      "position": NSNull(),
      "bounds": NSNull(),
      "opacity": NSNull()
    ]
    
    updateCornerPath()
  }
  
  override var bounds: NSRect {
    didSet {
      if bounds.size != oldValue.size {
        updateCornerPath()
      }
    }
  }
  
  private func updateCornerPath() {
    let path = NSBezierPath()
    let (start, arcFrom, arcTo) = calculatePoints()
    
    path.move(to: start)
    path.appendArc(from: arcFrom, to: arcTo, radius: radius)
    path.line(to: arcFrom)
    path.close()
    
    cornerPath = path
  }
  
  // 修正坐标计算（适配小窗口尺寸）
  private func calculatePoints() -> (start: NSPoint, arcFrom: NSPoint, arcTo: NSPoint) {
    switch cornerPosition {
    case .topLeft:
      return (
        NSPoint(x: 0, y: bounds.height - radius),
        NSPoint(x: 0, y: bounds.height),
        NSPoint(x: radius, y: bounds.height)
      )
    case .topRight:
      return (
        NSPoint(x: bounds.width, y: bounds.height - radius),
        NSPoint(x: bounds.width, y: bounds.height),
        NSPoint(x: bounds.width - radius, y: bounds.height)
      )
    case .bottomLeft:
      return (
        NSPoint(x: 0, y: radius),
        NSPoint(x: 0, y: 0),
        NSPoint(x: radius, y: 0)
      )
    case .bottomRight:
      return (
        NSPoint(x: bounds.width, y: radius),
        NSPoint(x: bounds.width, y: 0),
        NSPoint(x: bounds.width - radius, y: 0)
      )
    }
  }
  
  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    NSColor.black.setFill()
    cornerPath?.fill()
  }
}




