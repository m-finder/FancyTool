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
    let currentChangeCount = pasteboard.changeCount
    guard currentChangeCount != changeCount else { return }
    changeCount = currentChangeCount

    let sourceApp = NSWorkspace.shared.frontmostApplication
    let appIcon = sourceApp?.bundleURL?.path ?? "Unknown"

    if let copiedText = pasteboard.string(forType: .string) {
      let trimmedText = copiedText.trimmingCharacters(in: .whitespacesAndNewlines)

      if !trimmedText.isEmpty {
        append(PasterModel(content: copiedText, icon: appIcon))
      }
    }
    else if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
            let image = images.first {
      // TIFF、bitmap rep 和 PNG 会同时存在一段时间；剪贴板图片较大时，
      // 用局部 autorelease pool 避免这些临时对象堆积到主线程的事件循环末尾。
      autoreleasepool {
        if let imageData = image.tiffRepresentation,
           let bitmapImage = NSBitmapImageRep(data: imageData),
           let data = bitmapImage.representation(using: .png, properties: [:]) {
          append(PasterModel(image: data, icon: appIcon))
        }
      }
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

  // MARK: - 追加内容
  public func append(_ record: PasterModel){
    if let existingIndex = history.firstIndex(of: record) {
      // 重复剪贴板内容只移动已有对象，避免历史列表和磁盘文件重复增长。
      let existing = history.remove(at: existingIndex)
      existing.createdAt = Date()
      history.append(existing)
      sortHistory()
      save()
      return
    }

    history.append(record)
    sortHistory()
    trimHistory()
    save()
  }

  // MARK: - 删除数据
  public func remove(_ record: PasterModel) {
    guard let index = history.firstIndex(of: record) else { return }
    _ = history.remove(at: index)
    save()
  }

  // MARK: - 选中数据
  public func tap(_ item: PasterModel) {
    let success = self.copyToClipboard(item)
    guard success else { return }

    // 目标应用在快捷键触发时已捕获到 self.targetApp；
    // 此时 Paster 窗口已成为 key（NSApp.activate），再读 frontmostApplication
    // 会拿到 FancyTool 自己，导致激活目标 app 时其实是激活自己，窗口不会切换。
    guard let targetApp = self.targetApp else { return }
    self.hide()

    pasteTask?.cancel()
    pasteTask = Task { @MainActor [weak self] in
      do { try await Task.sleep(nanoseconds: 300_000_000) } catch { return }
      guard let self, !Task.isCancelled else { return }
      if self.state.autoPaste, self.hasAccessibilityPermission() {
        await self.simulatePaste(to: targetApp)
      } else {
        targetApp.activate(options: [.activateAllWindows])
      }
    }
  }

  // MARK: - 辅助功能权限（静默检查，不弹系统弹窗）
  private func hasAccessibilityPermission() -> Bool {
    let options = ["AXTrustedCheckOptionPrompt": false] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
  }

  // MARK: - 复制到剪切板
  public func copyToClipboard(_ item: PasterModel) -> Bool {
    pasteboard.clearContents()

    // 文本复制
    if let textContent = item.content, !textContent.isEmpty {
      let success = pasteboard.setString(textContent, forType: .string)
      if success, let copiedText = pasteboard.string(forType: .string), copiedText == item.content {
        // 这是 Paster 自己写入剪贴板的内容，避免下一次轮询把它再次记入历史。
        changeCount = pasteboard.changeCount
        return true
      } else {
        return false
      }
    }

    // 图片复制
    else if let imageData = item.image, let image = NSImage(data: imageData) {
      let success = pasteboard.writeObjects([image])
      if success, let pastedImages = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
         !pastedImages.isEmpty {
        changeCount = pasteboard.changeCount
        return true
      }
      return false
    }

    return false
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
    let limit = max(1, AppState.shared.historyCount)
    history = Array(PasterHistoryStore.load().prefix(limit))
    sortHistory()
  }

  private func trimHistory() {
    let limit = max(1, AppState.shared.historyCount)
    while history.count > limit {
      // history 已按置顶和创建时间排序，队尾是最旧的普通项；只有全部
      // 都置顶时才会淘汰最早置顶的记录。
      history.removeLast()
    }
  }

  public func togglePin(_ record: PasterModel) {
    guard history.contains(record) else { return }

    record.isPinned.toggle()
    sortHistory()
    trimHistory()
    save()
  }

  private func sortHistory() {
    history.sort {
      if $0.isPinned != $1.isPinned {
        return $0.isPinned
      }
      return $0.createdAt > $1.createdAt
    }
  }

  public func trimToLimit() {
    guard history.count > max(1, AppState.shared.historyCount) else { return }
    trimHistory()
    save()
  }

  private func save() {
    do {
      try PasterHistoryStore.save(history)
    } catch {
      // File I/O errors are normal Swift errors rather than uncatchable
      // Core Data exceptions. Keep the current in-memory history usable and
      // retry on the next mutation instead of terminating the menu-bar app.
      print("Failed to save paste history: \(error)")
    }
  }

}
