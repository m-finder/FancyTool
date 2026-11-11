import AppKit
import ApplicationServices

/// Opens the user's system control via Accessibility. Discovery happens only
/// after a click; waiting for presentation never repeats the activation.
@MainActor
enum DuoSystemPanel {
  case sound, displays, bluetooth, battery, inputSource

  private static var pendingOpen: Task<Void, Never>?
  private enum OpenResult { case opened, missingEntry, failed }
  private var requiresDirectEntry: Bool { self == .displays }

  private var owners: [String] {
    // macOS 27 moved system menu-bar items into MenuBarAgent. Their popover
    // windows still belong to ControlCenter or TextInputMenuAgent.
    let systemOwners = ["com.apple.MenuBarAgent", "com.apple.controlcenter", "com.apple.systemuiserver"]
    return self == .inputSource ? ["com.apple.TextInputMenuAgent"] + systemOwners : systemOwners
  }

  private var identifier: String {
    switch self {
    case .sound: "com.apple.menuextra.sound"
    case .displays: "com.apple.menuextra.display"
    case .bluetooth: "com.apple.menuextra.bluetooth"
    case .battery: "com.apple.menuextra.battery"
    case .inputSource: "com.apple.menuextra.textinput"
    }
  }
  private var moduleNames: [String] {
    switch self {
    case .sound: ["sound", "声音"]
    case .displays: ["display", "显示器"]
    case .bluetooth: ["bluetooth", "蓝牙"]
    case .battery: ["battery", "电池"]
    case .inputSource: []
    }
  }
  private var settings: DuoSettingsDestination {
    switch self {
    case .sound: .sound
    case .displays: .displays
    case .bluetooth: .bluetooth
    case .battery: .battery
    case .inputSource: .keyboard
    }
  }

  func open() {
    Self.pendingOpen?.cancel()
    Duo.shared.closePanel()
    guard AXIsProcessTrusted() else {
      if self == .displays { settings.open() }
      else { Self.showAccessibilityHelp() }
      return
    }
    Self.pendingOpen = Task {
      // Let the originating click finish and the Duo panel close before
      // asking another process to present its own window.
      await Task.yield()
      guard !Task.isCancelled else { return }
      let result = await openNativePanel()
      if result == .opened { return }
      guard !Task.isCancelled else { return }
      if result == .missingEntry && self == .displays { settings.open() }
      else { showUnavailableHelp() }
    }
  }

  private func openNativePanel() async -> OpenResult {
    let applications = owners.compactMap { owner -> (owner: String, root: AXUIElement)? in
      guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: owner).first else { return nil }
      return (owner, AXUIElementCreateApplication(app.processIdentifier))
    }
    let roots = applications.map(\.root)
    let centerRoot = applications.first { $0.owner == "com.apple.controlcenter" }?.root
    var centerItem: AXUIElement?
    var centerOwner: String?
    for (owner, root) in applications {
      guard !Task.isCancelled else { return .failed }
      let deadline = ProcessInfo.processInfo.systemUptime + 2
      let bars = [kAXExtrasMenuBarAttribute, kAXMenuBarAttribute].compactMap { Self.element(root, $0) }
      // Some versions expose a second menu bar only through AXChildren.
      let menuRoots = bars + Self.elements(root, kAXChildrenAttribute)
      let item = Self.find(in: menuRoots, until: deadline, where: {
        guard Self.string($0, kAXRoleAttribute) == kAXMenuBarItemRole else { return false }
        if Self.string($0, kAXIdentifierAttribute) == identifier { return true }
        // The input agent owns only the system input menu; some macOS versions
        // expose its menu-bar item without an accessibility identifier.
        return self == .inputSource && owner == "com.apple.TextInputMenuAgent"
      })
      if !requiresDirectEntry, centerItem == nil {
        centerItem = Self.find(in: menuRoots, until: deadline, where: {
          Self.string($0, kAXIdentifierAttribute) == "com.apple.menuextra.controlcenter"
        })
        if centerItem != nil { centerOwner = owner }
      }
      if let item {
        // Once an entry was activated, never open a second entry or Control
        // Center as a retry: the first presentation may still be completing.
        return await Self.openMenuBarItem(item, owner: owner, roots: roots) ? .opened : .failed
      }
    }
    // Displays need a standalone entry; the other controls can use Control Center.
    guard !requiresDirectEntry, self != .inputSource,
          let root = centerRoot, let center = centerItem, let owner = centerOwner else { return .missingEntry }
    guard !Task.isCancelled,
          await Self.openMenuBarItem(center, owner: owner, roots: roots) else { return .failed }
    // Give discovery and the newly created window separate time budgets.
    let deadline = ProcessInfo.processInfo.systemUptime + 3
    for _ in 0..<10 {
      do { try await Task.sleep(for: .milliseconds(120)) } catch { return .failed }
      guard ProcessInfo.processInfo.systemUptime < deadline else { break }
      let windows = Self.elements(root, kAXWindowsAttribute)
      // Control Center exposes a localized custom "show details" action.
      // AXShowMenu is a context menu; AXPress on a tile can toggle its setting.
      var detailsAction: String?
      if let tile = Self.find(in: windows, until: deadline, where: { element in
        guard matchesModule(element) else { return false }
        detailsAction = Self.actions(element).first { action in
          var description: CFString?
          _ = AXUIElementCopyActionDescription(element, action as CFString, &description)
          return Self.isDetailsAction(action, description: description as String? ?? "")
        }
        return detailsAction != nil
      }), let action = detailsAction, Self.perform(action, on: tile) == .success { return .opened }
      if let button = Self.find(in: windows, until: deadline, where: {
        guard matchesModule($0), Self.string($0, kAXRoleAttribute) == kAXButtonRole else { return false }
        let description = [Self.string($0, kAXIdentifierAttribute), Self.string($0, kAXTitleAttribute),
                           Self.string($0, kAXDescriptionAttribute)].joined(separator: " ").lowercased()
        return Self.isDetailsAction(description, description: "") || description.contains("expand") || description.contains("展开")
      }), Self.perform(kAXPressAction, on: button) == .success { return .opened }
    }
    return .failed
  }

  private static func showAccessibilityHelp() {
    let alert = NSAlert()
    alert.messageText = String(localized: "Allow Access to System Panels")
    alert.informativeText = String(localized: "Allow FancyTool in System Settings > Privacy & Security > Accessibility to open the original macOS menu-bar panels.")
    alert.addButton(withTitle: String(localized: "Open Accessibility Settings"))
    alert.addButton(withTitle: String(localized: "Cancel"))
    if alert.runModal() == .alertFirstButtonReturn,
       let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
      _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
      NSWorkspace.shared.open(url)
    }
  }

  private func showUnavailableHelp() {
    let alert = NSAlert()
    alert.messageText = String(localized: "System Panel Unavailable")
    alert.informativeText = String(localized: "macOS did not expose an entry for this panel. Show its system icon in the menu bar, then try again. You can also open its settings below.")
    alert.addButton(withTitle: String(localized: "Cancel"))
    alert.addButton(withTitle: String(localized: "Open Settings"))
    if alert.runModal() == .alertSecondButtonReturn { settings.open() }
  }

  private func matchesModule(_ element: AXUIElement) -> Bool {
    let text = [Self.string(element, kAXIdentifierAttribute), Self.string(element, kAXTitleAttribute),
                Self.string(element, kAXDescriptionAttribute)].joined(separator: " ").lowercased()
    return moduleNames.contains { text.contains($0) }
  }
  private static func value(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
    AXUIElementSetMessagingTimeout(element, 0.25)
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success ? value : nil
  }
  private static func string(_ element: AXUIElement, _ key: String) -> String { value(element, key) as? String ?? "" }
  private static func element(_ element: AXUIElement, _ key: String) -> AXUIElement? {
    guard let value = value(element, key), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
    return unsafeDowncast(value, to: AXUIElement.self)
  }
  private static func elements(_ element: AXUIElement, _ key: String) -> [AXUIElement] { value(element, key) as? [AXUIElement] ?? [] }
  private static func actions(_ element: AXUIElement) -> [String] {
    var actions: CFArray?
    guard AXUIElementCopyActionNames(element, &actions) == .success else { return [] }
    return actions as? [String] ?? []
  }
  private static let detailsNames: [String] = {
    let bundle = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.controlcenter").flatMap(Bundle.init(url:))
    return ["show details", "显示详细信息", "顯示詳細資訊", "顯示詳細資料",
            bundle?.localizedString(forKey: "show details", value: nil, table: nil) ?? "show details"]
  }()
  private static func isDetailsAction(_ action: String, description: String) -> Bool {
    let text = (action + " " + description).lowercased()
    return detailsNames.contains { text.contains($0.lowercased()) }
  }
  private static func perform(_ action: String, on element: AXUIElement) -> AXError {
    guard !Task.isCancelled else { return .cannotComplete }
    AXUIElementSetMessagingTimeout(element, 1)
    return AXUIElementPerformAction(element, action as CFString)
  }
  private static func openMenuBarItem(_ item: AXUIElement, owner: String, roots: [AXUIElement]) async -> Bool {
    let previousWindows = roots.flatMap { elements($0, kAXWindowsAttribute) }
    let previousVisibleWindows = visibleWindows(in: roots)
    // MenuBarAgent can acknowledge AXPress without opening the item. Send one
    // click using its current bounds instead of pressing and then clicking again.
    if owner == "com.apple.MenuBarAgent" {
      guard !Task.isCancelled, clickMenuBarItem(item) else { return false }
    } else {
      let result = perform(kAXPressAction, on: item)
      guard result == .success || result == .cannotComplete else { return false }
    }
    return await waitForPanel(item: item, roots: roots, previousWindows: previousWindows,
                              previousVisibleWindows: previousVisibleWindows)
  }
  private static func waitForPanel(item: AXUIElement, roots: [AXUIElement], previousWindows: [AXUIElement],
                                   previousVisibleWindows: Set<CGWindowID>) async -> Bool {
    for _ in 0..<8 {
      do { try await Task.sleep(for: .milliseconds(100)) } catch { return false }
      // Control Center may reuse an existing AX window when presenting a panel.
      if !visibleWindows(in: roots).subtracting(previousVisibleWindows).isEmpty { return true }
      if roots.flatMap({ elements($0, kAXWindowsAttribute) }).contains(where: { window in
        !previousWindows.contains { CFEqual($0, window) }
      }) { return true }
      if elements(item, kAXChildrenAttribute).contains(where: { string($0, kAXRoleAttribute) == kAXMenuRole }) { return true }
    }
    return false
  }
  private static func visibleWindows(in roots: [AXUIElement]) -> Set<CGWindowID> {
    let pids = Set(roots.compactMap { root -> pid_t? in
      var pid: pid_t = 0
      return AXUIElementGetPid(root, &pid) == .success ? pid : nil
    })
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
      as? [[String: Any]] ?? []
    return Set(windows.compactMap { window in
      guard let pid = window[kCGWindowOwnerPID as String] as? pid_t, pids.contains(pid) else { return nil }
      return window[kCGWindowNumber as String] as? CGWindowID
    })
  }
  private static func clickMenuBarItem(_ item: AXUIElement) -> Bool {
    guard let position = value(item, kAXPositionAttribute), CFGetTypeID(position) == AXValueGetTypeID(),
          let size = value(item, kAXSizeAttribute), CFGetTypeID(size) == AXValueGetTypeID() else { return false }
    var origin = CGPoint.zero
    var dimensions = CGSize.zero
    guard AXValueGetValue(unsafeDowncast(position, to: AXValue.self), .cgPoint, &origin),
          AXValueGetValue(unsafeDowncast(size, to: AXValue.self), .cgSize, &dimensions),
          dimensions.width > 0, dimensions.height > 0 else { return false }
    let point = CGPoint(x: origin.x + dimensions.width / 2, y: origin.y + dimensions.height / 2)
    let screenTop = NSScreen.screens.first?.frame.maxY ?? 0
    let screenPoint = NSPoint(x: point.x, y: screenTop - point.y)
    guard NSScreen.screens.contains(where: { $0.frame.contains(screenPoint) }),
          let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left),
          let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left) else { return false }
    down.flags = []
    up.flags = []
    down.post(tap: .cghidEventTap)
    up.post(tap: .cghidEventTap)
    return true
  }
  private static func find(in roots: [AXUIElement], until deadline: TimeInterval,
                           where predicate: (AXUIElement) -> Bool) -> AXUIElement? {
    var queue = roots
    var index = 0
    var visited = Set<AXUIElement>()
    while index < queue.count, index < 160, !Task.isCancelled, ProcessInfo.processInfo.systemUptime < deadline {
      let element = queue[index]
      index += 1
      guard visited.insert(element).inserted else { continue }
      if predicate(element) { return element }
      queue.append(contentsOf: elements(element, kAXChildrenAttribute))
    }
    return nil
  }
}
