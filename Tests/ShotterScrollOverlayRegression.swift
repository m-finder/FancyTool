import AppKit
import CoreMedia
import ScreenCaptureKit

private func bluePixelCount(_ image: CGImage) -> Int {
  let context = CGContext(data: nil, width: image.width, height: image.height,
    bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
  let pixels = context.data!.assumingMemoryBound(to: UInt8.self)
  return stride(from: 0, to: image.width * image.height * 4, by: 4).reduce(0) { count, index in
    count + (Int(pixels[index + 2]) - Int(pixels[index]) > 30 &&
      Int(pixels[index + 2]) - Int(pixels[index + 1]) > 15 ? 1 : 0)
  }
}

private final class OverlayEvents: @unchecked Sendable {
  private let lock = NSLock()
  private var previews = 0
  private var bluePixels = 0
  func receive(_ event: ShotterScrollFrameProcessor.Event) {
    if case let .preview(preview) = event {
      let count = bluePixelCount(preview.image)
      lock.withLock { previews += 1; bluePixels += count }
    }
  }
  func verify() {
    lock.withLock {
      precondition(previews > 0 && bluePixels == 0, "Preview captured a screenshot overlay")
    }
  }
}

@MainActor
private final class GrayscaleScrollView: NSView {
  var offset: CGFloat = 0 { didSet { needsDisplay = true } }
  override var isFlipped: Bool { true }
  override func draw(_ dirtyRect: NSRect) {
    NSColor.white.setFill()
    bounds.fill()
    for y in stride(from: Int(offset) - Int(offset) % 20,
      through: Int(offset + bounds.height), by: 20) {
      for x in stride(from: 0, through: Int(bounds.width), by: 19) {
        let value = abs((y &* 1597 &+ x &* 7841) ^ (y &* x &* 73))
        NSColor(white: CGFloat(value % 160) / 255, alpha: 1).setFill()
        CGRect(x: CGFloat(x), y: CGFloat(y) - offset, width: 11,
          height: CGFloat(4 + value % 9)).fill()
      }
    }
  }
}

@MainActor
private final class OverlayRegression: NSObject, NSApplicationDelegate {
  private var windows: [NSWindow] = []

  func applicationDidFinishLaunching(_ notification: Notification) {
    setbuf(stdout, nil)
    Task {
      do { try await run(); finish(0) }
      catch { print("FAIL overlay capture:", error); finish(1) }
    }
  }

  private func run() async throws {
    guard CGPreflightScreenCaptureAccess(), let screen = NSScreen.main,
      let identifier = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
    else { throw NSError(domain: "Screen recording access required", code: 1) }
    let source = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
    source.isReleasedWhenClosed = false
    source.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue - 1)
    source.title = "FancyTool owned screenshot overlay regression"
    let view = GrayscaleScrollView(frame: CGRect(origin: .zero, size: screen.frame.size))
    source.contentView = view
    source.orderFrontRegardless()
    windows.append(source)
    try await Task.sleep(for: .milliseconds(200))

    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    let display = content.displays.first { $0.displayID == identifier.uint32Value }!
    let application = content.applications.first { $0.processID == ProcessInfo.processInfo.processIdentifier }!
    precondition(content.windows.contains { $0.windowID == CGWindowID(source.windowNumber) },
      "Source window was not enumerated")
    let selection = CGRect(x: screen.frame.width / 2 - 160, y: screen.frame.height / 2 - 60,
      width: 320, height: 120)
    let region = ShotterScrollCaptureRegion(selection: selection,
      bounds: CGRect(origin: .zero, size: screen.frame.size), scale: screen.backingScaleFactor)

    let borderRect = CGRect(x: screen.frame.minX + selection.minX,
      y: screen.frame.maxY - selection.maxY, width: selection.width, height: selection.height)
    let border = NSPanel(contentRect: borderRect.insetBy(dx: -3, dy: -3),
      styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    border.isReleasedWhenClosed = false
    border.isOpaque = false
    border.backgroundColor = .clear
    border.hasShadow = false
    border.ignoresMouseEvents = true
    border.level = .screenSaver
    let borderView = NSView(frame: CGRect(origin: .zero, size: border.frame.size))
    borderView.wantsLayer = true
    borderView.layer?.borderWidth = 2
    borderView.layer?.borderColor = NSColor.systemBlue.cgColor
    border.contentView = borderView
    border.orderFrontRegardless()
    windows.append(border)
    let filter = ShotterScrollContentFilter.make(display: display, application: application,
      windows: content.windows, excludingWindowIDs: [CGWindowID(border.windowNumber)])
    let configuration = SCStreamConfiguration()
    configuration.sourceRect = region.sourceRect
    configuration.width = region.width
    configuration.height = region.height
    configuration.scalesToFit = false
    configuration.showsCursor = false
    configuration.pixelFormat = kCVPixelFormatType_32BGRA
    configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
    configuration.queueDepth = 3
    try await Task.sleep(for: .milliseconds(100))
    let contaminated = try await SCScreenshotManager.captureImage(
      contentFilter: SCContentFilter(display: display, excludingWindows: []), configuration: configuration)
    precondition(bluePixelCount(contaminated) > 0, "Regression did not exercise the visible blue border")
    let snapshot = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
    precondition(bluePixelCount(snapshot) == 0, "Snapshot captured an unenumerated border")

    let events = OverlayEvents()
    let processor = ShotterScrollFrameProcessor(topInset: region.topInset, bottomInset: region.bottomInset) {
      events.receive($0)
    }
    let stream = SCStream(filter: filter, configuration: configuration, delegate: processor)
    processor.setActiveStream(stream)
    try stream.addStreamOutput(processor, type: .screen, sampleHandlerQueue: processor.deliveryQueue)
    try await stream.startCapture()
    try processor.commitActiveStream(stream)
    try await Task.sleep(for: .milliseconds(100))
    for index in 0..<40 {
      view.offset += CGFloat([8, 18, 36, 60][index % 4])
      try await Task.sleep(for: .milliseconds(index % 7 == 6 ? 160 : 50))
    }
    try await Task.sleep(for: .milliseconds(150))
    try await stream.stopCapture()
    await processor.finishPendingFrames()
    let final = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
    _ = await processor.appendFinalImage(final)
    let output = await processor.makeImage()!
    precondition(output.width == Int(selection.width * screen.backingScaleFactor), "Output lost native resolution")
    precondition(output.height == Int((selection.height + view.offset) * screen.backingScaleFactor),
      "Excluding overlays lost the source window or scroll content")
    precondition(bluePixelCount(output) == 0, "Export contains repeated blue lines")
    events.verify()
    print("PASS unenumerated overlay: snapshot, live preview, export, own-app content, native resolution")
  }

  private func finish(_ status: Int32) {
    windows.forEach { $0.orderOut(nil); $0.close() }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exit(status) }
  }
}

@main
private struct ShotterScrollOverlayRegression {
  @MainActor static func main() {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = OverlayRegression()
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
  }
}
