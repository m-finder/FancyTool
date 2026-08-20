import AppKit
import Foundation
import KeyboardShortcuts

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

  /// Creates a display-local physical-pixel rectangle for
  /// CGDisplayCreateImage(_:rect:).
  static func displayLocalQuartzRect(fromAppKit rect: NSRect, on screen: NSScreen) -> CGRect? {
    guard let displayID = displayID(for: screen) else { return nil }
    let portion = rect.intersection(screen.frame)
    guard !portion.isNull, !portion.isEmpty,
          screen.frame.width > 0, screen.frame.height > 0 else {
      return nil
    }

    let displayBounds = CGDisplayBounds(displayID)
    let xScale = displayBounds.width / screen.frame.width
    let yScale = displayBounds.height / screen.frame.height
    return CGRect(
      x: (portion.minX - screen.frame.minX) * xScale,
      y: (screen.frame.maxY - portion.maxY) * yScale,
      width: portion.width * xScale,
      height: portion.height * yScale
    ).integral
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
    guard controller.start() else { return }
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
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }

      let image: CGImage?
      if let windowID = selection.windowID {
        image = CGWindowListCreateImage(
          .null,
          .optionIncludingWindow,
          windowID,
          [.bestResolution, .boundsIgnoreFraming]
        )
      } else {
        image = self.captureDisplays(in: selection.rect)
      }

      guard let image, image.width > 0, image.height > 0 else {
        print("[Shotter] unable to capture selected area")
        return
      }

      let imageSize = selection.rect.size
      self.showImage(NSImage(cgImage: image, size: imageSize), at: selection.rect)
    }
  }

  /// Captures each intersecting display in its own coordinate space and
  /// composites the result in AppKit selection coordinates. This avoids relying
  /// on a single global conversion, which breaks when displays are positioned
  /// above/below one another or use different backing scales.
  private func captureDisplays(in selectionRect: NSRect) -> CGImage? {
    let portions: [(screen: NSScreen, displayID: CGDirectDisplayID, rect: NSRect)] = NSScreen.screens.compactMap { screen in
      guard let displayID = ShotterCoordinateSpace.displayID(for: screen) else { return nil }
      let portion = selectionRect.intersection(screen.frame)
      guard !portion.isNull, !portion.isEmpty else { return nil }
      return (screen, displayID, portion)
    }
    guard !portions.isEmpty else { return nil }

    let outputScale = portions.map { ShotterCoordinateSpace.backingScale(for: $0.screen) }.max() ?? 1
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
      guard let captureRect = ShotterCoordinateSpace.displayLocalQuartzRect(fromAppKit: portion.rect, on: portion.screen),
            let displayImage = CGDisplayCreateImage(portion.displayID, rect: captureRect) else {
        continue
      }

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
