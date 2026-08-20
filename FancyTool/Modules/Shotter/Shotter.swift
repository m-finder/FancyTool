import AppKit
import Foundation
import KeyboardShortcuts

struct ShotterCaptureSelection {
  let rect: NSRect
  let windowID: CGWindowID?
}

enum ShotterCoordinateSpace {

  static var primaryDisplayTop: CGFloat {
    let mainDisplay = CGMainDisplayID()
    return NSScreen.screens.first { screen in
      guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
        return false
      }
      return CGDirectDisplayID(number.uint32Value) == mainDisplay
    }?.frame.maxY ?? NSScreen.screens.first?.frame.maxY ?? 0
  }

  static func quartzRect(fromAppKit rect: NSRect) -> CGRect {
    CGRect(
      x: rect.minX,
      y: primaryDisplayTop - rect.maxY,
      width: rect.width,
      height: rect.height
    )
  }

  static func appKitRect(fromQuartz rect: CGRect) -> NSRect {
    NSRect(
      x: rect.minX,
      y: primaryDisplayTop - rect.maxY,
      width: rect.width,
      height: rect.height
    )
  }
}

@MainActor
final class Shotter {

  static let shared = Shotter()

  private var imageWindows: [ShotterImageWindow] = []
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
        image = CGWindowListCreateImage(
          ShotterCoordinateSpace.quartzRect(fromAppKit: selection.rect),
          .optionOnScreenOnly,
          kCGNullWindowID,
          [.bestResolution, .boundsIgnoreFraming]
        )
      }

      guard let image, image.width > 0, image.height > 0 else {
        print("[Shotter] unable to capture selected area")
        return
      }

      let scale = NSScreen.screens.first { $0.frame.intersects(selection.rect) }?.backingScaleFactor ?? 1
      let imageSize = NSSize(
        width: CGFloat(image.width) / scale,
        height: CGFloat(image.height) / scale
      )
      self.showImage(NSImage(cgImage: image, size: imageSize), at: selection.rect)
    }
  }

  private func finishSelection() {
    selectionController = nil
    isCapturing = false
  }

  private func closeImageWindows() {
    imageWindows.forEach { $0.dismissWindow() }
  }

  private func showImage(_ image: NSImage, at selectionRect: NSRect?) {
    let window = ShotterImageWindow(image: image, selectionRect: selectionRect)
    imageWindows.append(window)
    window.onClose = { [weak self, weak window] in
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self, weak window] in
        guard let window else { return }
        self?.imageWindows.removeAll { $0 === window }
      }
    }
    NSApp.activate(ignoringOtherApps: true)
    window.show()
  }
}
