//
//  Runner.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/8/25.
//

import AppKit
import Combine

@MainActor
final class Runner {

  public static let shared = Runner()

  private var item: NSStatusItem

  // MARK: - 速度属性
  private var fps: Double {
    let usage = AppState.shared.bundle?.cpuInfo?.percentage.value ?? 0
    return RunnerConfig.minFPS + (RunnerConfig.maxFPS - RunnerConfig.minFPS) * (usage / 100)
  }

  private var cancellables = Set<AnyCancellable>()

  init(){
    self.item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  }

  // MARK: - 计算属性
  private var currentScale: CGFloat {
    item.button?.window?.screen?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
  }

  // MARK: - 挂载
  public func mount() {

    guard let button = item.button else { return }

    // 挂载动画层
    RunnerLayer.shared.mount(button: button, scale: currentScale)

    // 添加屏幕和窗口监听
    observe()

    // 刷新挂载的图片
    reload()

    // 挂载菜单
    item.menu = AppMenu.shared.getMenus()
  }

  // MARK: - 刷新挂载的图片
  private func reload() {

    if RunnerFrame.shared.runner != nil {
      // 加载图片帧
      _ = RunnerFrame.shared.refresh(for: currentScale)

      // 取到第一张图
      guard let first = RunnerFrame.shared.refresh(for: currentScale).first else {
          item.length = RunnerConfig.baseSize
          return
      }

      // 计算宽度并应用
      let width = RunnerConfig.baseSize * CGFloat(first.width) / CGFloat(first.height)
      item.length = width
      item.button?.frame.size.width = width
      RunnerLayer.shared.layer?.frame = item.button?.bounds ?? .zero
      animation()
      return
    }

    // 卸载动画 layer
    RunnerLayer.shared.unmount()
    // 刷新为默认图标和尺寸
    item.length = RunnerConfig.defaultIconSize
    item.button?.image = NSImage(named: RunnerConfig.defaultIconName)?.resized(to: RunnerConfig.defaultIconSize)
  }

  // MARK: - 刷新选中的runner
  public func change() {

    if RunnerFrame.shared.runner == nil {
      RunnerLayer.shared.layer?.contents = nil
    }

    RunnerFrame.shared.cache.removeAll()
    RunnerModel.clearImageCache()
    reload()
  }


  // MARK: - 动画处理
  private func animation() {
    guard let layer = RunnerLayer.shared.layer else { return }

    let scale = layer.contentsScale
    let frames = RunnerFrame.shared.refresh(for: scale)
    guard !frames.isEmpty else { return }

    item.button?.image = nil
    layer.isHidden = false

    // 把 frame 跟按钮当前 bounds 对齐，防止图片宽度不撑开
    layer.frame = item.button?.bounds ?? .zero

    layer.contents = frames.first

    layer.removeAnimation(forKey: "runner")
    layer.add(makeAnimation(values: frames, fps: fps), forKey: "runner")
  }

  private func makeAnimation(values: [Any], fps: Double) -> CAKeyframeAnimation {
    let animation = CAKeyframeAnimation(keyPath: "contents")
    animation.values = values
    animation.keyTimes = (0..<values.count).map {
      NSNumber(value: Double($0) / Double(values.count))
    }
    animation.duration = Double(values.count) / fps
    animation.repeatCount = .infinity
    animation.calculationMode = .discrete
    animation.isRemovedOnCompletion = false
    return animation
  }

  // MARK: - 屏幕变化监听
  private func observe() {
    cancellables.removeAll()

    NotificationCenter.default
      .publisher(for: NSApplication.didChangeScreenParametersNotification)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.handleScreenChanged()
      }
      .store(in: &cancellables)

    if let window = item.button?.window {
      NotificationCenter.default
        .publisher(for: NSWindow.didChangeScreenNotification, object: window)
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
          self?.handleScreenChanged()
      }
      .store(in: &cancellables)
    }
  }

  private func handleScreenChanged() {
    let newScale = currentScale

    RunnerFrame.shared.cache.removeValue(forKey: newScale)
    _ = RunnerFrame.shared.refresh(for: newScale)

    RunnerLayer.shared.layer?.contentsScale = newScale
    animation()
  }
}
