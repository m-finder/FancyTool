//
//  RounderView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/19.
//

import SwiftUI

@MainActor
class RounderView: NSView {
  
  public var radius: CGFloat {
    didSet {
      guard radius != oldValue else { return }
      needsDisplay = true
      refresh()
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
    refresh()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override var bounds: NSRect {
    didSet {
      if bounds.size != oldValue.size {
        refresh()
      }
    }
  }
  
  private func refresh() {
    let path = NSBezierPath()
    let (start, arcFrom, arcTo) = calculate()
    
    path.move(to: start)
    path.appendArc(from: arcFrom, to: arcTo, radius: radius)
    path.line(to: arcFrom)
    path.close()
    
    cornerPath = path
  }
  
  // 修正坐标计算
  private func calculate() -> (start: NSPoint, arcFrom: NSPoint, arcTo: NSPoint) {
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




