import AppKit
import CoreGraphics
import Foundation
import ScreenCaptureKit

struct ShotterCaptureSelection {
  enum Mode {
    case image
    case scrolling
  }

  let rect: NSRect
  let windowID: CGWindowID?
  var mode: Mode = .image
  var targetProcessID: pid_t? = nil
}

enum ShotterCoordinateSpace {

  private static var primaryDisplayTop: CGFloat {
    let mainDisplay = CGMainDisplayID()
    return NSScreen.screens.first { screen in
      displayID(for: screen) == mainDisplay
    }?.frame.maxY ?? NSScreen.main?.frame.maxY ?? 0
  }

  static func screen(containing point: NSPoint) -> NSScreen? {
    NSScreen.screens.first { screen in
      screen.frame.contains(point)
    }
  }

  static func screen(for rect: NSRect) -> NSScreen? {
    NSScreen.screens.max { lhs, rhs in
      intersectionArea(lhs.frame, rect) < intersectionArea(rhs.frame, rect)
    }.flatMap { screen in
      intersectionArea(screen.frame, rect) > 0 ? screen : ShotterCoordinateSpace.screen(containing: NSPoint(x: rect.midX, y: rect.midY))
    }
  }

  /// CGWindowList uses the global Quartz screen space: its origin is at the
  /// upper-left of the primary display, while AppKit's origin is lower-left.
  /// Those coordinates remain in points, even on Retina displays.
  static func quartzPoint(fromAppKit point: NSPoint) -> CGPoint {
    CGPoint(x: point.x, y: primaryDisplayTop - point.y)
  }

  static func quartzRect(fromAppKit rect: NSRect) -> CGRect {
    CGRect(
      x: rect.minX,
      y: primaryDisplayTop - rect.maxY,
      width: rect.width,
      height: rect.height
    )
  }

  static func appKitRects(fromQuartz rect: CGRect) -> [NSRect] {
    [NSRect(
      x: rect.minX,
      y: primaryDisplayTop - rect.maxY,
      width: rect.width,
      height: rect.height
    )]
  }

  static func boundingAppKitRect(fromQuartz rect: CGRect) -> NSRect {
    NSRect(
      x: rect.minX,
      y: primaryDisplayTop - rect.maxY,
      width: rect.width,
      height: rect.height
    )
  }

  /// Creates a display-local logical-point rectangle for
  /// SCStreamConfiguration.sourceRect. ScreenCaptureKit uses an upper-left
  /// origin in each display's logical coordinate space.
  static func displayLocalScreenCaptureRect(fromAppKit rect: NSRect, on screen: NSScreen) -> CGRect? {
    let portion = rect.intersection(screen.frame)
    guard !portion.isNull, !portion.isEmpty,
          screen.frame.width > 0, screen.frame.height > 0 else {
      return nil
    }

    return CGRect(
      x: portion.minX - screen.frame.minX,
      y: screen.frame.maxY - portion.maxY,
      width: portion.width,
      height: portion.height
    )
  }

  static func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
    guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
      return nil
    }
    return CGDirectDisplayID(number.uint32Value)
  }

  private static func intersectionArea(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
    let intersection = lhs.intersection(rhs)
    guard !intersection.isNull, !intersection.isEmpty else { return 0 }
    return intersection.width * intersection.height
  }
}

@MainActor
final class Shotter {

  static let shared = Shotter()

  // Preview windows opt out of AppKit's legacy release-on-close behavior, so
  // these handles own their lifetime until AppKit's close transaction settles.
  private var imageWindows: [ShotterImageWindowHandle] = []
  // Holds windows closed by unmount until AppKit's deferred cleanup finishes.
  private var retiringImageWindows: [ShotterImageWindowHandle] = []
  private var selectionController: ShotterSelectionController?
  private var scrollCaptureController: ShotterScrollCaptureController?
  private var captureTask: Task<Void, Never>?
  private var isMounted = false

  private init() {}

  public func mount() {
    isMounted = true
    ShotterShortcut.shared.mount { [weak self] in
      self?.startSelection()
    }
  }

  public func unmount() {
    isMounted = false
    ShotterShortcut.shared.unmount()
    cancelSelection()
    closeImageWindows()
  }

  public func startSelection(mode: ShotterCaptureSelection.Mode = .image) {
    guard isMounted, selectionController == nil, scrollCaptureController == nil, captureTask == nil else { return }
    guard ensureScreenCapturePermission() else { return }

    let targetApp = NSWorkspace.shared.frontmostApplication
    let controller = ShotterSelectionController(mode: mode)
    controller.onComplete = { [weak self, weak controller] selection in
      guard let self, let controller, self.selectionController === controller else { return }
      let selectedApp = selection.targetProcessID.flatMap { NSRunningApplication(processIdentifier: $0) } ?? targetApp
      if selection.mode == .scrolling {
        self.startScrollCapture(selection: selection, targetApp: selectedApp)
      } else {
        self.capture(selection: selection, targetApp: selectedApp)
      }
    }
    controller.onCancel = { [weak self, weak controller] in
      guard let self, let controller, self.selectionController === controller else { return }
      self.selectionController = nil
    }
    selectionController = controller
    if !controller.start() { selectionController = nil }
  }

  private func ensureScreenCapturePermission() -> Bool {
    guard !CGPreflightScreenCaptureAccess() else { return true }

    NSApp.activate(ignoringOtherApps: true)
    _ = CGRequestScreenCaptureAccess()
    guard CGPreflightScreenCaptureAccess() else {
      let alert = NSAlert()
      alert.alertStyle = .warning
      alert.messageText = String(localized: "Screen Recording Permission Required")
      alert.informativeText = String(localized: "Allow FancyTool in System Settings → Privacy & Security → Screen Recording, then restart FancyTool before taking a screenshot.")
      alert.addButton(withTitle: String(localized: "Open Settings"))
      alert.addButton(withTitle: String(localized: "Cancel"))

      if alert.runModal() == .alertFirstButtonReturn,
         let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
        NSWorkspace.shared.open(url)
      }
      return false
    }

    return true
  }

  public func cancelSelection() {
    captureTask?.cancel()
    captureTask = nil
    let controller = selectionController
    selectionController = nil
    controller?.cancel()
    let scrollController = scrollCaptureController
    scrollCaptureController = nil
    scrollController?.cancel()
  }

  private func startScrollCapture(selection: ShotterCaptureSelection, targetApp: NSRunningApplication?) {
    selectionController = nil
    let controller = ShotterScrollCaptureController()
    scrollCaptureController = controller
    controller.onComplete = { [weak self, weak controller] image, scale in
      guard let self, let controller, self.scrollCaptureController === controller else { return }
      self.scrollCaptureController = nil
      self.captureTask?.cancel()
      self.captureTask = nil
      let size = NSSize(width: CGFloat(image.width) / max(scale, 1), height: CGFloat(image.height) / max(scale, 1))
      self.showImage(NSImage(cgImage: image, size: size), sourceCGImage: image, at: nil)
    }
    controller.onCancel = { [weak self, weak controller] in
      guard let self, let controller, self.scrollCaptureController === controller else { return }
      self.scrollCaptureController = nil
      self.captureTask?.cancel()
      self.captureTask = nil
    }
    controller.onError = { [weak self, weak controller] error in
      guard let self, let controller, self.scrollCaptureController === controller else { return }
      self.scrollCaptureController = nil
      self.captureTask?.cancel()
      self.captureTask = nil
      self.showScrollCaptureError(error)
    }

    captureTask = Task { [weak self, weak controller] in
      do {
        // Let AppKit remove the selection overlay before the stream starts.
        try await Task.sleep(nanoseconds: 80_000_000)
        guard !Task.isCancelled, let self, let controller,
              self.scrollCaptureController === controller else { return }
        try await controller.start(in: selection.rect, targetApp: targetApp)
        guard !Task.isCancelled, self.scrollCaptureController === controller else { return }
        self.captureTask = nil
      } catch {
        guard !Task.isCancelled, let self, let controller,
              self.scrollCaptureController === controller else { return }
        self.captureTask = nil
        self.scrollCaptureController = nil
        controller.cancel()
        self.showScrollCaptureError(error)
      }
    }
  }

  private func showScrollCaptureError(_ error: Error) {
    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = String(localized: "Could not start scrolling capture")
    alert.informativeText = error.localizedDescription
    alert.addButton(withTitle: String(localized: "OK"))
    NSApp.activate(ignoringOtherApps: true)
    alert.runModal()
  }

  private func capture(selection: ShotterCaptureSelection, targetApp: NSRunningApplication?) {
    selectionController = nil

    // The selection overlay is above every application. Capture on the next
    // run-loop turn so it has been removed from the window server first.
    captureTask = Task { [weak self] in
      do {
        try await Task.sleep(nanoseconds: 80_000_000)
      } catch { return }
      guard !Task.isCancelled, let self else { return }
      let image = await self.captureImage(for: selection)
      guard !Task.isCancelled else { return }
      self.captureTask = nil
      guard let image, image.width > 0, image.height > 0 else {
        print("[Shotter] unable to capture selected area")
        self.showCaptureError()
        return
      }

      let imageSize = selection.rect.size
      let canScroll = selection.rect.width >= 80 && selection.rect.height >= 80
        && NSScreen.screens.contains { $0.frame.contains(selection.rect) }
      let startScrolling: (() -> Void)? = canScroll ? { [weak self] in
        guard let self, self.isMounted, self.selectionController == nil,
              self.scrollCaptureController == nil, self.captureTask == nil else { return }
        var scrollingSelection = selection
        scrollingSelection.mode = .scrolling
        self.startScrollCapture(selection: scrollingSelection, targetApp: targetApp)
      } : nil
      self.showImage(NSImage(cgImage: image, size: imageSize), sourceCGImage: image, at: selection.rect,
                     onStartScrollingCapture: startScrolling)
    }
  }

  /// Captures once through ScreenCaptureKit. It is the supported replacement
  /// for CGWindowListCreateImage and CGDisplayCreateImage, and avoids the
  /// deprecated Quartz screenshot APIs on every supported macOS release.
  private func captureImage(for selection: ShotterCaptureSelection) async -> CGImage? {
    do {
      let content = try await SCShareableContent.excludingDesktopWindows(
        false,
        onScreenWindowsOnly: true
      )
      try Task.checkCancellation()

      if let windowID = selection.windowID {
        return try await captureWindow(windowID: windowID, from: content)
      }
      return try await captureSelection(in: selection.rect, from: content)
    } catch is CancellationError {
      return nil
    } catch {
      print("[Shotter] ScreenCaptureKit capture failed: \(error.localizedDescription)")
      return nil
    }
  }

  private func captureWindow(
    windowID: CGWindowID,
    from content: SCShareableContent
  ) async throws -> CGImage? {
    guard let window = content.windows.first(where: { $0.windowID == windowID }) else {
      return nil
    }

    let filter = SCContentFilter(desktopIndependentWindow: window)
    let configuration = SCStreamConfiguration()
    configuration.showsCursor = false
    // Never let ScreenCaptureKit upscale a source to satisfy the requested size.
    // The requested dimensions below already match the display's native pixels.
    configuration.scalesToFit = false

    // SCScreenshotManager defaults to 1920×1080. Explicit physical-pixel
    // dimensions preserve Retina detail instead of silently scaling a window.
    let scale = max(CGFloat(filter.pointPixelScale), 1)
    configuration.width = max(1, Int((window.frame.width * scale).rounded(.up)))
    configuration.height = max(1, Int((window.frame.height * scale).rounded(.up)))
    return try await SCScreenshotManager.captureImage(
      contentFilter: filter,
      configuration: configuration
    )
  }

  private func captureSelection(
    in selectionRect: NSRect,
    from content: SCShareableContent
  ) async throws -> CGImage? {
    // Capture every intersected display explicitly and composite the result.
    // This avoids SCScreenshotManager.captureImage(in:)'s default dimensions,
    // which can downscale small/Retina selections and make previews blurry.
    return try await captureDisplays(in: selectionRect, from: content)
  }

  /// Captures each intersecting display through ScreenCaptureKit and composites
  /// the result in AppKit selection coordinates at physical-pixel resolution.
  private func captureDisplays(
    in selectionRect: NSRect,
    from content: SCShareableContent
  ) async throws -> CGImage? {
    let portions: [(screen: NSScreen, display: SCDisplay, rect: NSRect, scale: CGFloat)] = NSScreen.screens.compactMap { screen in
      guard let displayID = ShotterCoordinateSpace.displayID(for: screen),
            let display = content.displays.first(where: { $0.displayID == displayID }) else {
        return nil
      }
      let portion = selectionRect.intersection(screen.frame)
      guard !portion.isNull, !portion.isEmpty else { return nil }
      let filter = SCContentFilter(display: display, excludingWindows: [])
      return (screen, display, portion, max(CGFloat(filter.pointPixelScale), 1))
    }
    guard !portions.isEmpty else { return nil }

    let outputScale = portions.map(\.scale).max() ?? 1
    let outputWidth = max(1, Int((selectionRect.width * outputScale).rounded(.up)))
    let outputHeight = max(1, Int((selectionRect.height * outputScale).rounded(.up)))
    guard let context = CGContext(
      data: nil,
      width: outputWidth,
      height: outputHeight,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
      return nil
    }

    context.interpolationQuality = .high
    for portion in portions {
      try Task.checkCancellation()
      guard let sourceRect = ShotterCoordinateSpace.displayLocalScreenCaptureRect(
        fromAppKit: portion.rect,
        on: portion.screen
      ) else {
        continue
      }

      let filter = SCContentFilter(display: portion.display, excludingWindows: [])
      let configuration = SCStreamConfiguration()
      configuration.showsCursor = false
      configuration.scalesToFit = false
      configuration.sourceRect = sourceRect
      configuration.width = max(1, Int((sourceRect.width * portion.scale).rounded(.up)))
      configuration.height = max(1, Int((sourceRect.height * portion.scale).rounded(.up)))

      let displayImage = try await SCScreenshotManager.captureImage(
        contentFilter: filter,
        configuration: configuration
      )
      try Task.checkCancellation()
      // Align every edge to an integral output pixel. A fractional destination
      // makes Core Graphics resample even when source and destination have the
      // same native scale, which is visible as a soft 1px blur on Retina text.
      let destinationX = ((portion.rect.minX - selectionRect.minX) * outputScale).rounded()
      let destinationY = ((portion.rect.minY - selectionRect.minY) * outputScale).rounded()
      let destinationWidth = (portion.rect.width * outputScale).rounded()
      let destinationHeight = (portion.rect.height * outputScale).rounded()
      let destination = CGRect(
        x: destinationX,
        y: destinationY,
        width: max(1, destinationWidth),
        height: max(1, destinationHeight)
      )
#if DEBUG
      let actualScaleX = CGFloat(displayImage.width) / max(sourceRect.width, 1)
      let actualScaleY = CGFloat(displayImage.height) / max(sourceRect.height, 1)
      print(String(format: "[Shotter] portion points=%@ requested=%zux%zu actual=%zux%zu scale=%.2fx%.2f", NSStringFromSize(sourceRect.size), configuration.width, configuration.height, displayImage.width, displayImage.height, actualScaleX, actualScaleY))
#endif
      context.draw(displayImage, in: destination)
    }
    return context.makeImage()
  }

  private func showCaptureError() {
    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = String(localized: "Could not capture this area")
    alert.informativeText = String(localized: "The window may have closed or screen recording access may have changed. Try selecting the area again.")
    alert.addButton(withTitle: String(localized: "Try Again"))
    alert.addButton(withTitle: String(localized: "Cancel"))
    NSApp.activate(ignoringOtherApps: true)
    if alert.runModal() == .alertFirstButtonReturn { startSelection() }
  }

  private func closeImageWindows() {
    // Detach the handles before closing. Each handle owns a preview window
    // whose legacy release-on-close behavior is disabled in its initializer.
    let handles = imageWindows
    imageWindows.removeAll(keepingCapacity: false)
    retainUntilCloseSettles(handles)
    handles.forEach { $0.dismiss() }
  }

  private func retainUntilCloseSettles(_ handles: [ShotterImageWindowHandle]) {
    guard !handles.isEmpty else { return }
    retiringImageWindows.append(contentsOf: handles)
    let identifiers = Set(handles.map(ObjectIdentifier.init))
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
      self?.retiringImageWindows.removeAll { identifiers.contains(ObjectIdentifier($0)) }
    }
  }

  private func showImage(_ image: NSImage, sourceCGImage: CGImage? = nil, at selectionRect: NSRect?,
                         onStartScrollingCapture: (() -> Void)? = nil) {
    let window = ShotterImageWindow(image: image, sourceCGImage: sourceCGImage, selectionRect: selectionRect,
                                    onStartScrollingCapture: onStartScrollingCapture)
    let handle = ShotterImageWindowHandle(window: window)
    imageWindows.append(handle)
    window.onClose = { [weak self, weak handle] in
      // AppKit schedules window/display cleanup after windowWillClose. Keep the
      // window alive through that work, then release its owning handle once the
      // close transaction and the following display cycle have settled.
      DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self, weak handle] in
        guard let handle else { return }
        self?.imageWindows.removeAll { $0 === handle }
      }
    }
    NSApp.activate(ignoringOtherApps: true)
    window.show()
  }
}

@MainActor
private final class ShotterImageWindowHandle {

  private var window: ShotterImageWindow?

  init(window: ShotterImageWindow) {
    self.window = window
  }

  func dismiss() {
    guard let window else { return }
    window.onClose = nil
    window.dismissWindow()
  }
}
