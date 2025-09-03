//
//  Runner.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/8/25.
//

import SwiftUI

class Runner {
  
  public static let shared = Runner()
  
  private var index: Int = 0
  private var runnerTimer: DispatchSourceTimer?
  public var runner: RunnerModel? {
    RunnerHandler.shared.getRunnerById(AppState.shared.runnerId) ?? nil
  }
  
  // MARK: - 挂载
  public func mound(to item: NSStatusItem){
    if let button = item.button {
      if let image = NSImage(named: "m-finder") {
        image.size = NSSize(width: 28, height: 28)
        button.image = image
        button.target = self
      }
    }
    // 初始化菜单
    item.menu = AppMenu.shared.getMenus()
  }
  
  // MARK: - 刷新
  public func refresh(for item: NSStatusItem, usage: Double){
    self.runnerTimer?.cancel()
    
    let interval = Double(0.2 / max(1.0, min(20.0, usage / 5.0)))
    let runnerQueue = DispatchQueue(label: "runner.timer", qos: .utility)
    self.runnerTimer = DispatchSource.makeTimerSource(queue: runnerQueue)
    self.runnerTimer?.schedule(deadline: .now(), repeating: interval)
    self.runnerTimer?.setEventHandler { [weak self] in
      if let self = self, let runner = runner {
        index = (index + 1) % (runner.frameNumber)
        DispatchQueue.main.async {
          item.button?.image = NSImage(cgImage: runner.getImage(self.index), size: NSSize(width: 24, height: 24))
        }
      }
    }
    self.runnerTimer?.resume()
  }
  
}
