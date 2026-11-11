//
//  Paster.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/19.
//
import AppKit
import SwiftUI
import Foundation
import Combine
import KeyboardShortcuts

@MainActor
class Paster: ObservableObject{

  private let store = PasterHistoryStore()
  private var capturePending = false
  private var timer: Timer?
  private var isMounted = false
  private var shortcutRegistered = false
  private var systemSleeping = false
  private var displaySleeping = false
  private var sleepObservers = Set<AnyCancellable>()
  private var pasteTask: Task<Void, Never>?
  public var changeCount: Int
  public static let shared = Paster()

  private let state = AppState.shared
  @Published public private(set) var history: [PasterModel] = []

  public var window: PasterHistoryWindow?
  private let pasteboard = NSPasteboard.general
  private var targetApp: NSRunningApplication?

  init(){
    changeCount = pasteboard.changeCount
    loadHistory()
  }

  // MARK: - 挂载
  public func mount(){
    guard !isMounted else { return }
    isMounted = true
    observeSleep()
    startPolling()

    // The shortcut package appends handlers; register once across enable cycles.
    if !shortcutRegistered {
      shortcutRegistered = true
      KeyboardShortcuts.onKeyUp(for: .paster) { [weak self] in
        DispatchQueue.main.async {
          guard let self, self.isMounted else { return }
          self.targetApp = NSWorkspace.shared.frontmostApplication
          if self.window?.isVisible == true { self.hide() } else { self.show() }
        }
      }
    }
    KeyboardShortcuts.enable(.paster)
  }

  private func startPolling() {
    guard isMounted, !systemSleeping, !displaySleeping, timer == nil else { return }

    // NSPasteboard 没有可靠的变更通知，只能轮询 changeCount。
    // 使用 tolerance 让系统合并定时器唤醒，避免每次都精确唤醒主线程，
    // 同时保留约 2 秒的剪贴板响应延迟。真正读取文本/图片只在 changeCount 变化时进行。
    timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self, self.isMounted, !self.systemSleeping, !self.displaySleeping else { return }
        self.pollClipboard()
      }
    }
    timer?.tolerance = 1
    if let timer {
      RunLoop.main.add(timer, forMode: .common)
    }

  }

  private func stopPolling() {
    timer?.invalidate()
    timer = nil
  }

  private func observeSleep() {
    let workspace = NSWorkspace.shared.notificationCenter
    for name in [NSWorkspace.willSleepNotification, NSWorkspace.didWakeNotification,
                 NSWorkspace.screensDidSleepNotification, NSWorkspace.screensDidWakeNotification] {
      workspace.publisher(for: name)
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in
          guard let self, self.isMounted else { return }
          switch name {
          case NSWorkspace.willSleepNotification: self.systemSleeping = true
          case NSWorkspace.didWakeNotification: self.systemSleeping = false
          case NSWorkspace.screensDidSleepNotification: self.displaySleeping = true
          default: self.displaySleeping = false
          }
          if self.systemSleeping || self.displaySleeping {
            self.stopPolling()
          } else {
            self.pollClipboard()
            self.startPolling()
          }
        }
        .store(in: &sleepObservers)
    }
  }

  // MARK: - 剪贴板监听
  func pollClipboard(){
    guard !capturePending else { return }
    let currentChangeCount = pasteboard.changeCount
    guard currentChangeCount != changeCount else { return }
    changeCount = currentChangeCount
    let icon = NSWorkspace.shared.frontmostApplication?.bundleURL?.path ?? "Unknown"
    let capture: PasterHistoryStore.Capture
    if let text = pasteboard.string(forType: .string),
       !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      capture = .text(text)
    } else if let data = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff) {
      // Transfer encoded bytes; all decoding and PNG/thumbnail work stays off the UI thread.
      capture = .image(data)
    } else { return }
    capturePending = true
    store.capture(capture, icon: icon, limit: state.historyCount) { [weak self] result in
      self?.capturePending = false
      self?.receive(result)
    }
  }

  // MARK: - 取消挂载
  public func unmount(){
    isMounted = false
    stopPolling()
    sleepObservers.removeAll()
    systemSleeping = false
    displaySleeping = false
    pasteTask?.cancel()
    pasteTask = nil
    KeyboardShortcuts.disable(.paster)
    hide()
    targetApp = nil
  }

  // MARK: - 显示窗口
  public func show(){
    pasteTask?.cancel()
    pasteTask = nil
    if self.window == nil {
      self.window = PasterHistoryWindow(contentView: PasterView())
      self.window?.isReleasedWhenClosed = false
    }

    NSApp.activate(ignoringOtherApps: true)
    self.window?.makeKeyAndOrderFront(nil)
    self.window?.orderFrontRegardless()
  }

  // MARK: - 隐藏窗口
  public func hide(){
    let window = self.window
    self.window = nil
    window?.close()
  }

  // MARK: - 删除数据
  public func remove(_ record: PasterModel) {
    store.remove(id: record.id, limit: state.historyCount) { [weak self] in self?.receive($0) }
  }

  // MARK: - 选中数据
  public func tap(_ item: PasterModel) {
    let application = targetApp
    pasteTask?.cancel()
    pasteTask = Task { @MainActor [weak self] in
      guard let self, await self.copyToClipboard(item), !Task.isCancelled else { return }
      self.hide()
      guard let application else { return }
      do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
      if self.state.autoPaste, self.hasAccessibilityPermission() {
        await self.simulatePaste(to: application)
      } else {
        application.activate(options: [.activateAllWindows])
      }
    }
  }

  // MARK: - 辅助功能权限（静默检查，不弹系统弹窗）
  private func hasAccessibilityPermission() -> Bool {
    let options = ["AXTrustedCheckOptionPrompt": false] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
  }

  // MARK: - 复制到剪切板
  public func copyToClipboard(_ item: PasterModel) async -> Bool {
    let image: Data?
    if let name = item.imageFileName { image = await store.media(named: name) }
    else { image = nil }
    guard !Task.isCancelled else { return false }
    guard item.content != nil || image != nil else { return false }
    pasteboard.clearContents()
    let success: Bool
    if let text = item.content {
      success = pasteboard.setString(text, forType: .string)
    } else if let image {
      success = pasteboard.setData(image, forType: .png)
    } else { return false }
    if success { changeCount = pasteboard.changeCount }
    return success
  }

  func thumbnail(for item: PasterModel) async -> Data? {
    guard let name = item.thumbnailFileName else { return nil }
    return await store.media(named: name)
  }

  // MARK: - 模拟粘贴
  public func simulatePaste(to application: NSRunningApplication? = nil) async {
    let targetApp = application ?? self.targetApp
    guard await requestAccessibilityPermission() else { return }

    guard let source = CGEventSource(stateID: .hidSystemState) else {
      return
    }

    targetApp?.activate(options: [.activateAllWindows])
    do { try await Task.sleep(nanoseconds: 100_000_000) } catch { return }
    guard !Task.isCancelled else { return }
    // 模拟完整的 Command+V 粘贴操作
    let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
    let vKeyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
    let vKeyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
    let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)

    cmdDown?.flags = .maskCommand
    vKeyDown?.flags = .maskCommand

    // 设置事件目标进程
    if let pid = targetApp?.processIdentifier {
      cmdDown?.postToPid(pid)
      usleep(1000)
      vKeyDown?.postToPid(pid)
      vKeyUp?.postToPid(pid)
      cmdUp?.postToPid(pid)
    }
  }

  // MARK: - 辅助功能权限申请
  private func requestAccessibilityPermission() async -> Bool {
      // 快速判断：已经授权就返回
      let quickOptions = ["AXTrustedCheckOptionPrompt": false] as CFDictionary
      if AXIsProcessTrustedWithOptions(quickOptions) { return true }

      // 未授权 → 弹系统设置，并等待用户完成授权
      let promptOptions = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
      AXIsProcessTrustedWithOptions(promptOptions)

      for _ in 0..<40 {
        do { try await Task.sleep(nanoseconds: 500_000_000) } catch { return false }
        if AXIsProcessTrustedWithOptions(quickOptions) { return true }
      }

      let alert = NSAlert()
      alert.messageText = NSLocalizedString("Need Accessibility Permissions", comment: "Alert title for accessibility permission request")
      alert.informativeText = NSLocalizedString("Please enable permissions for this app in System Settings > Security & Privacy > Privacy > Accessibility to allow paste operations.", comment: "Detailed explanation for accessibility permission request")
      alert.addButton(withTitle: NSLocalizedString("OK", comment: "Confirm button text"))
      alert.runModal()
      return AXIsProcessTrustedWithOptions(quickOptions)
  }

  // MARK: - 持久化
  private func loadHistory() {
    store.load(limit: state.historyCount) { [weak self] in self?.receive($0) }
  }

  public func togglePin(_ record: PasterModel) {
    store.togglePin(id: record.id, limit: state.historyCount) { [weak self] in self?.receive($0) }
  }

  public func trimToLimit() {
    store.load(limit: state.historyCount) { [weak self] in self?.receive($0) }
  }

  private func receive(_ result: Result<[PasterModel], Error>) {
    switch result {
    case .success(let records): history = records
    case .failure(let error): print("Failed to update paste history: \(error)")
    }
  }
}
