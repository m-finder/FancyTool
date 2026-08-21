import AppKit
import Foundation
import KeyboardShortcuts
import ScreenCaptureKit

struct ShotterCaptureSelection {
  let rect: NSRect
  let windowID: CGWindowID?
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

  static func appKitPoint(fromQuartz point: CGPoint) -> NSPoint {
    NSPoint(x: point.x, y: primaryDisplayTop - point.y)
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

  static func backingScale(for screen: NSScreen) -> CGFloat {
    guard let displayID = displayID(for: screen), screen.frame.width > 0, screen.frame.height > 0 else {
      return screen.backingScaleFactor
    }
    let displayBounds = CGDisplayBounds(displayID)
    return max(displayBounds.width / screen.frame.width, displayBounds.height / screen.frame.height)
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
  private var isCapturing = false
  private var shortcutHandlerInstalled = false

  private init() {}

  public func mount() {
    if shortcutHandlerInstalled {
      KeyboardShortcuts.enable(.shotter)
    } else {
      KeyboardShortcuts.onKeyUp(for: .shotter) { [weak self] in
        DispatchQueue.main.async {
          self?.startSelection()
        }
      }
      shortcutHandlerInstalled = true
    }
  }

  public func unmount() {
    KeyboardShortcuts.disable(.shotter)
    cancelSelection()
    closeImageWindows()
  }

  public func startSelection() {
    guard !isCapturing else { return }

    let controller = ShotterSelectionController()
    controller.onComplete = { [weak self] selection in
      self?.capture(selection: selection)
    }
    controller.onCancel = { [weak self] in
      self?.finishSelection()
    }
    guard controller.start() else {
      finishSelection()
      return
    }
    selectionController = controller
    isCapturing = true
  }

  public func cancelSelection() {
    guard isCapturing else { return }
    let controller = selectionController
    finishSelection()
    controller?.cancel()
  }

  private func capture(selection: ShotterCaptureSelection) {
    finishSelection()

    // The selection overlay is above every application. Capture on the next
    // run-loop turn so it has been removed from the window server first.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
      guard let self else { return }

      Task { [weak self] in
        guard let self else { return }
        let image = await self.captureImage(for: selection)
        guard let image, image.width > 0, image.height > 0 else {
          print("[Shotter] unable to capture selected area")
          return
        }

        let imageSize = selection.rect.size
        self.showImage(NSImage(cgImage: image, size: imageSize), at: selection.rect)
      }
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

      if let windowID = selection.windowID {
        return try await captureWindow(windowID: windowID, from: content)
      }
      return try await captureSelection(in: selection.rect, from: content)
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

    context.interpolationQuality = .none
    for portion in portions {
      guard let sourceRect = ShotterCoordinateSpace.displayLocalScreenCaptureRect(
        fromAppKit: portion.rect,
        on: portion.screen
      ) else {
        continue
      }

      let filter = SCContentFilter(display: portion.display, excludingWindows: [])
      let configuration = SCStreamConfiguration()
      configuration.showsCursor = false
      configuration.sourceRect = sourceRect
      configuration.width = max(1, Int((sourceRect.width * portion.scale).rounded(.up)))
      configuration.height = max(1, Int((sourceRect.height * portion.scale).rounded(.up)))

      let displayImage = try await SCScreenshotManager.captureImage(
        contentFilter: filter,
        configuration: configuration
      )
      let destination = CGRect(
        x: (portion.rect.minX - selectionRect.minX) * outputScale,
        y: (portion.rect.minY - selectionRect.minY) * outputScale,
        width: portion.rect.width * outputScale,
        height: portion.rect.height * outputScale
      )
      context.draw(displayImage, in: destination)
    }
    return context.makeImage()
  }

  private func finishSelection() {
    selectionController = nil
    isCapturing = false
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

  private func showImage(_ image: NSImage, at selectionRect: NSRect?) {
    let window = ShotterImageWindow(image: image, selectionRect: selectionRect)
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
