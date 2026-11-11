import AppKit
import SwiftUI

private struct AppVersion: Comparable {
  let parts: [Int]

  init?(_ value: String) {
    let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let number = value.first == "v" || value.first == "V" ? String(value.dropFirst()) : value
    let components = number.split(separator: ".", omittingEmptySubsequences: false)
    guard !components.isEmpty,
          components.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }),
          components.allSatisfy({ Int($0) != nil }) else { return nil }
    parts = components.compactMap { Int($0) }
  }

  static func < (lhs: Self, rhs: Self) -> Bool {
    for index in 0..<max(lhs.parts.count, rhs.parts.count) {
      let left = index < lhs.parts.count ? lhs.parts[index] : 0
      let right = index < rhs.parts.count ? rhs.parts[index] : 0
      if left != right { return left < right }
    }
    return false
  }
}

private struct GitHubRelease: Decodable {
  let tag_name: String
  let html_url: URL
  let draft: Bool
  let prerelease: Bool
}

@MainActor
final class UpdateChecker {
  static let shared = UpdateChecker()

  private enum Result {
    case available(version: String, url: URL)
    case current
    case failed
  }

  private let lastCheckKey = "lastUpdateCheck"
  private let lastPromptedVersionKey = "lastPromptedUpdateVersion"
  private let checkInterval: TimeInterval = 24 * 60 * 60
  private let releasesURL = URL(string: "https://api.github.com/repos/m-finder/FancyTool/releases/latest")!
  private var timer: Timer?
  private var request: (id: UUID, task: Task<Result, Never>)?
  private var popover: NSPopover?

  private init() {}

  func start() {
    guard timer == nil else { return }
    timer = Timer.scheduledTimer(withTimeInterval: 60 * 60, repeats: true) { [weak self] _ in
      Task { @MainActor [weak self] in await self?.checkAutomatically() }
    }
    timer?.tolerance = 5 * 60
    Task { await checkAutomatically() }
  }

  func checkManually() async {
    switch await check() {
    case let .available(version, url):
      if !showBubble(version: version, url: url) {
        showAlert(message: String(localized: "New Version Available"), detail: version, releaseURL: url)
      }
    case .current:
      showAlert(message: String(localized: "Update Check"), detail: String(localized: "You're up to date."))
    case .failed:
      showAlert(message: String(localized: "Update Check"), detail: String(localized: "Unable to check for updates."))
    }
  }

  private func checkAutomatically() async {
    if let lastCheck = UserDefaults.standard.object(forKey: lastCheckKey) as? Date {
      let elapsed = Date().timeIntervalSince(lastCheck)
      if elapsed >= 0 && elapsed < checkInterval { return }
    }
    guard case let .available(version, url) = await check(),
          UserDefaults.standard.string(forKey: lastPromptedVersionKey) != version else { return }
    showBubble(version: version, url: url)
  }

  private func check() async -> Result {
    let active: (id: UUID, task: Task<Result, Never>)
    if let request {
      active = request
    } else {
      UserDefaults.standard.set(Date(), forKey: lastCheckKey)
      active = (UUID(), Task { await fetchRelease() })
      request = active
    }
    let result = await active.task.value
    if request?.id == active.id { request = nil }
    return result
  }

  private func fetchRelease() async -> Result {
    guard let currentString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
          let current = AppVersion(currentString) else { return .failed }
    var request = URLRequest(url: releasesURL)
    request.timeoutInterval = 12
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.setValue("FancyTool", forHTTPHeaderField: "User-Agent")
    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let response = response as? HTTPURLResponse, response.statusCode == 200 else { return .failed }
      let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
      guard !release.draft, !release.prerelease,
            release.html_url.scheme == "https", release.html_url.host == "github.com",
            let latest = AppVersion(release.tag_name) else { return .failed }
      return latest > current ? .available(version: release.tag_name, url: release.html_url) : .current
    } catch {
      return .failed
    }
  }

  @discardableResult
  private func showBubble(version: String, url: URL) -> Bool {
    guard let button = Runner.shared.statusButton else { return false }
    popover?.close()
    let popover = NSPopover()
    popover.behavior = .transient
    popover.contentSize = NSSize(width: 270, height: 118)
    popover.contentViewController = NSHostingController(rootView: UpdateBubbleView(
      version: version,
      onOpen: { [weak self] in
        self?.popover?.close()
        NSWorkspace.shared.open(url)
      },
      onDismiss: { [weak self] in self?.popover?.close() }
    ))
    self.popover = popover
    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    if popover.isShown { UserDefaults.standard.set(version, forKey: lastPromptedVersionKey) }
    return popover.isShown
  }

  private func showAlert(message: String, detail: String, releaseURL: URL? = nil) {
    let alert = NSAlert()
    alert.messageText = message
    alert.informativeText = detail
    if releaseURL != nil { alert.addButton(withTitle: String(localized: "View Release")) }
    alert.addButton(withTitle: String(localized: "OK"))
    NSApp.activate(ignoringOtherApps: true)
    if alert.runModal() == .alertFirstButtonReturn, let releaseURL {
      NSWorkspace.shared.open(releaseURL)
    }
  }
}

private struct UpdateBubbleView: View {
  let version: String
  let onOpen: () -> Void
  let onDismiss: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("New Version Available", systemImage: "arrow.down.circle.fill")
        .font(.system(size: 13, weight: .semibold))
      Text(String(format: String(localized: "Version %@ is available."), version))
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
      HStack {
        Spacer()
        Button("Later", action: onDismiss)
        Button("View Release", action: onOpen)
          .buttonStyle(.borderedProminent)
      }
    }
    .padding(14)
    .frame(width: 270)
  }
}
