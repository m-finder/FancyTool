//
//  RounderView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/19.
//

import SwiftUI

class RounderView: NSView {
  
  private var radius: CGFloat
  
  init(frame frameRect: NSRect, radius: CGFloat) {
    self.radius = radius
    super.init(frame: frameRect)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func draw(_ dirtyRect: NSRect) {
    // 绘制透明背景
    NSColor.clear.set()
    dirtyRect.fill()
    
    // 设置绘制颜色为黑色
    NSColor.black.set()
    
    // 绘制四个角落
    drawCorner(at: .topLeft)
    drawCorner(at: .topRight)
    drawCorner(at: .bottomLeft)
    drawCorner(at: .bottomRight)
  }
  
  // 定义角落位置的枚举
  private enum CornerPosition {
    case topLeft, topRight, bottomLeft, bottomRight
  }
  
  // 通用方法：绘制单个角落
  private func drawCorner(at position: CornerPosition) {
    let path = NSBezierPath()
    
    // 根据角落位置计算三个关键点的坐标
    let (startPoint, arcFromPoint, arcToPoint) = calculatePoints(for: position)
    
    // 绘制路径
    path.move(to: startPoint)
    path.appendArc(from: arcFromPoint, to: arcToPoint, radius: radius)
    path.line(to: arcFromPoint)
    path.close()
    
    // 填充路径
    path.lineWidth = 0
    path.fill()
  }
  
  // 计算指定角落的三个关键点坐标
  private func calculatePoints(for position: CornerPosition) -> (start: NSPoint, arcFrom: NSPoint, arcTo: NSPoint) {
    switch position {
    case .topLeft:
      return (
        NSPoint(x: bounds.minX, y: bounds.maxY - radius),
        NSPoint(x: bounds.minX, y: bounds.maxY),
        NSPoint(x: bounds.minX + radius, y: bounds.maxY)
      )
    case .topRight:
      return (
        NSPoint(x: bounds.maxX, y: bounds.maxY - radius),
        NSPoint(x: bounds.maxX, y: bounds.maxY),
        NSPoint(x: bounds.maxX - radius, y: bounds.maxY)
      )
    case .bottomLeft:
      return (
        NSPoint(x: bounds.minX, y: bounds.minY + radius),
        NSPoint(x: bounds.minX, y: bounds.minY),
        NSPoint(x: bounds.minX + radius, y: bounds.minY)
      )
    case .bottomRight:
      return (
        NSPoint(x: bounds.maxX, y: bounds.minY + radius),
        NSPoint(x: bounds.maxX, y: bounds.minY),
        NSPoint(x: bounds.maxX - radius, y: bounds.minY)
      )
    }
  }
}


