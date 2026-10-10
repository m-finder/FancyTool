//
//  Hidder.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//

import AppKit
import SwiftUI

@MainActor
extension NSStatusItem {
  var isExpanded: Bool {
    get { length == Hidder.shared.length }
    set { length = newValue ? Hidder.shared.length : CGFloat(Hidder.shared.size) }
  }
}

@MainActor
class Hidder {

  public static let shared = Hidder()

  /// macOS 27 调整了菜单栏的收纳规则，旧的 status item 宽度机制不再可靠。
  /// 在该系统及更高版本隐藏此功能，避免产生空白状态项或错误布局。
  nonisolated public static var isSupported: Bool {
    if #available(macOS 27.0, *) {
      return false
    }
    return true
  }

  public var length: CGFloat = 10000
  private var items: [NSStatusItem] = []

  public var size: Int {
    AppState.shared.hidderSize
  }

  private var leftItem: NSStatusItem? {
    items.min(by: {
      ($0.button?.window?.frame.minX ?? .greatestFiniteMagnitude) <
        ($1.button?.window?.frame.minX ?? .greatestFiniteMagnitude)
    })
  }

  // MARK: - 挂载
  public func mount(toggleAfterMount: Bool = false){
    guard Self.isSupported else {
      unmount()
      return
    }

    self.unmount()

    // 验证状态栏可用性
    let testItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    guard testItem.button != nil else {
      print("StatusBar is not available, retry mounting later")
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
        self?.mount(toggleAfterMount: toggleAfterMount)
      }
      return
    }
    NSStatusBar.system.removeStatusItem(testItem)
    for _ in 0..<2 {

      let item: NSStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

      if let button = item.button, let image = NSImage(named: NSImage.Name("Circle")) {
        image.size = NSSize(width: size, height: size)
        image.isTemplate = true

        button.image = image
        button.target = AppMenuActions.shared
        button.action = #selector(AppMenuActions.toggle(_:))
      }

      self.items.append(item)
    }

    if toggleAfterMount {
      toggle()
    }

  }

  // MARK: - 取消挂载
  public func unmount(){

    for item in items {
      if let button = item.button {
        button.image = nil
      }
      NSStatusBar.system.removeStatusItem(item)
    }
    items.removeAll()

  }

  // MARK: - 显示｜隐藏控制
  public func toggle() {
    guard Self.isSupported else { return }
    self.leftItem?.isExpanded.toggle()
  }

  // MARK: - 刷新 hidder 图标的尺寸
  public func refresh() {
    guard Self.isSupported else { return }

    let newSize = CGFloat(size)

    for item in items {
      if let button = item.button, let image = NSImage(named: NSImage.Name("Circle")) {
        image.size = NSSize(width: newSize, height: newSize)
        image.isTemplate = true
        button.image = image
      }
    }
  }

}
