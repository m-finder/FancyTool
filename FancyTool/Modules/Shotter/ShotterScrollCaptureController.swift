import AppKit
import Combine
import CoreMedia
import Darwin
import ScreenCaptureKit

enum ShotterScrollCaptureError: LocalizedError {
  case invalidArea
  case areaTooLarge
  case displayUnavailable
  case noFrames

  var errorDescription: String? {
    switch self {
    case .invalidArea:
      String(localized: "Choose an area of at least 80 × 80 points within one display.")
    case .areaTooLarge:
      String(localized: "Choose a smaller area for a scrolling screenshot.")
    case .displayUnavailable:
      String(localized: "The display changed. Start a new scrolling screenshot.")
    case .noFrames:
      String(localized: "No frames were captured. Try selecting the area again.")
    }
  }
}

/// Captures a fixed viewport while the user scrolls the underlying application.
/// The border never accepts input, and the controls do not activate FancyTool.
@MainActor
final class ShotterScrollCaptureController {
  var onComplete: ((CGImage, CGFloat) -> Void)?
  var onCancel: (() -> Void)?
  var onError: ((Error) -> Void)?

  private enum State { case idle, starting, recording, interrupted, finishing, stopped }

  private var state = State.idle
  private var stream: SCStream?
  private var frameProcessor: ShotterScrollFrameProcessor?
  private var controls: ShotterScrollControlsPanel?
  private var border: NSPanel?
  private var screenObserver: AnyCancellable?
  private var recoveryTask: Task<Void, Never>?
  private var streamFailure: ShotterScrollFrameProcessor.StreamFailure?
  private var scrollMonitor: Any?
  private var localScrollMonitor: Any?
  private var lastScrollUptime: TimeInterval = 0
  private var nextStreamRestartUptime: TimeInterval = 0
  private var restartFailures = 0
  private var displayID: CGDirectDisplayID?
  private var displayFrame = NSRect.zero
  private var displayScale: CGFloat = 1
  private var outputScale: CGFloat = 1
  private var capturedHeight = 0
  private var captureFilter: SCContentFilter?
  private var captureConfiguration: SCStreamConfiguration?
  private var snapshotConfiguration: SCStreamConfiguration?
  private var latestProgress: ShotterScrollFrameProcessor.Progress?

  func start(in rect: NSRect, targetApp: NSRunningApplication?) async throws {
    guard state == .idle else { throw CancellationError() }
    guard rect.width.isFinite, rect.height.isFinite,
          rect.width >= 80, rect.height >= 80,
          let screen = NSScreen.screens.first(where: { $0.frame.contains(rect) }),
          let identifier = ShotterCoordinateSpace.displayID(for: screen),
          let sourceRect = ShotterCoordinateSpace.displayLocalScreenCaptureRect(fromAppKit: rect, on: screen) else {
      throw ShotterScrollCaptureError.invalidArea
    }

    state = .starting
    displayID = identifier
    displayFrame = screen.frame
    displayScale = screen.backingScaleFactor
    showWindows(around: rect, on: screen)
    scrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] _ in
      guard let self, rect.contains(NSEvent.mouseLocation) else { return }
      self.didScroll()
    }
    localScrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
      if rect.contains(NSEvent.mouseLocation) {
        self?.didScroll()
      }
      return event
    }
    observeDisplayChanges()

    do {
      let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
      try checkStarting()
      guard let display = content.displays.first(where: { $0.displayID == identifier }) else {
        throw ShotterScrollCaptureError.displayUnavailable
      }
      let sessionWindowIDs = Set([border, controls].compactMap { window in
        window.map { CGWindowID($0.windowNumber) }
      })
      guard let application = content.applications.first(where: {
        $0.processID == ProcessInfo.processInfo.processIdentifier
      }) else { throw ShotterScrollCaptureError.noFrames }
      let filter = ShotterScrollContentFilter.make(display: display, application: application,
        windows: content.windows, excludingWindowIDs: sessionWindowIDs)
      outputScale = max(1, screen.backingScaleFactor)
      let region = ShotterScrollCaptureRegion(selection: sourceRect,
        bounds: CGRect(origin: .zero, size: screen.frame.size), scale: outputScale)
      let width = region.width
      let height = region.height
      guard width <= 40_000_000 / height else { throw ShotterScrollCaptureError.areaTooLarge }

      let configuration = SCStreamConfiguration()
      configuration.sourceRect = region.sourceRect
      configuration.width = width
      configuration.height = height
      configuration.scalesToFit = false
      configuration.showsCursor = false
      configuration.capturesAudio = false
      configuration.pixelFormat = kCVPixelFormatType_32BGRA
      configuration.colorSpaceName = CGColorSpace.sRGB
      configuration.queueDepth = 3
      configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
      captureFilter = filter
      captureConfiguration = configuration
      let snapshotConfiguration = SCStreamConfiguration()
      snapshotConfiguration.sourceRect = region.sourceRect
      snapshotConfiguration.width = width
      snapshotConfiguration.height = height
      snapshotConfiguration.scalesToFit = false
      snapshotConfiguration.showsCursor = false
      snapshotConfiguration.pixelFormat = kCVPixelFormatType_32BGRA
      snapshotConfiguration.colorSpaceName = CGColorSpace.sRGB
      self.snapshotConfiguration = snapshotConfiguration

      let events = ShotterScrollEventRelay { [weak self] event in self?.receive(event) }
      let processor = ShotterScrollFrameProcessor(topInset: region.topInset, bottomInset: region.bottomInset) { events.send($0) }
      let stream = SCStream(filter: filter, configuration: configuration, delegate: processor)
      processor.setActiveStream(stream)
      self.frameProcessor = processor
      self.stream = stream
      try stream.addStreamOutput(processor, type: .screen, sampleHandlerQueue: processor.deliveryQueue)
      if let targetApp, targetApp.processIdentifier != ProcessInfo.processInfo.processIdentifier,
         !targetApp.isTerminated {
        targetApp.activate(options: [])
      }
      try await stream.startCapture()
      try checkStarting()
      try processor.commitActiveStream(stream)
      state = .recording
      startRecovery()
      if let latestProgress {
        showProgress(latestProgress)
      }
    } catch {
      stopResources()
      state = .stopped
      throw error
    }
  }

  func cancel() {
    guard state != .stopped else { return }
    state = .stopped
    let callback = onCancel
    clearCallbacks()
    stopResources()
    callback?()
  }

  private func checkStarting() throws {
    try Task.checkCancellation()
    guard state == .starting else { throw CancellationError() }
  }

  private func receive(_ event: ShotterScrollFrameProcessor.Event) {
    guard state == .starting || state == .recording || state == .finishing || state == .interrupted else { return }
    switch event {
    case let .progress(update, width, height, _, _):
      guard state == .starting || state == .recording else { return }
      let progress = ShotterScrollFrameProcessor.Progress(update: update, width: width, height: height)
      guard progress != latestProgress else { return }
      latestProgress = progress
      // A stream may deliver its first buffer before startCapture returns.
      // Keep the controls in their preparing state until startup completes.
      guard state == .recording else { return }
      showProgress(progress)
    case let .preview(preview):
      controls?.setPreview(preview.image)
    case let .failure(failure):
      guard state == .recording, frameProcessor?.isCurrentFailure(failure) == true else { return }
      if failure.canRetry {
        streamFailure = failure
        nextStreamRestartUptime = 0
        startRecovery()
        controls?.setStatus(String(localized: "Capture stalled. Reconnecting…"), height: capturedHeight)
      } else {
        interruptOrFail(failure.error)
      }
    }
  }

  private func showProgress(_ progress: ShotterScrollFrameProcessor.Progress) {
    capturedHeight = progress.height
    controls?.setCapturedSize(width: progress.width, height: progress.height)
    controls?.finishButton.isEnabled = progress.height > 0
    let message: String
    switch progress.update {
    case .appended, .unchanged:
      message = String(localized: "Scroll down slowly inside the selected area.")
    case .noOverlap:
      message = String(localized: "Unable to match the latest frame.")
    case .limitReached:
      // Reaching the limit must not silently export a truncated screenshot.
      pauseCapture(message: String(localized: "Size limit reached. Finish to keep the preview, or cancel and select a smaller area."))
      return
    }
    controls?.setStatus(message, height: progress.height)
  }

  private func finish() {
    guard state == .recording || state == .interrupted, let frameProcessor else { return }
    state = .finishing
    recoveryTask?.cancel()
    recoveryTask = nil
    screenObserver = nil
    if let scrollMonitor { NSEvent.removeMonitor(scrollMonitor) }
    scrollMonitor = nil
    if let localScrollMonitor { NSEvent.removeMonitor(localScrollMonitor) }
    localScrollMonitor = nil
    controls?.finishButton.isEnabled = false
    controls?.setStatus(String(localized: "Finishing…"), height: capturedHeight)
    let stream = self.stream
    self.stream = nil
    Task { try? await stream?.stopCapture() }
    Task { [weak self, frameProcessor] in
      await frameProcessor.finishPendingFrames()
      let image = await frameProcessor.makeImage()
      guard let self, self.state == .finishing else { return }
      guard let image else {
        self.fail(ShotterScrollCaptureError.noFrames)
        return
      }
      let callback = self.onComplete
      self.clearCallbacks()
      self.state = .stopped
      self.frameProcessor = nil
      self.captureFilter = nil
      self.captureConfiguration = nil
      self.snapshotConfiguration = nil
      self.closeWindows()
      callback?(image, self.outputScale)
    }
  }

  private func fail(_ error: Error) {
    guard state != .stopped else { return }
    state = .stopped
    let callback = onError
    clearCallbacks()
    stopResources()
    callback?(error)
  }

  private func interruptOrFail(_ error: Error) {
    guard state == .recording, capturedHeight > 0 else {
      fail(error)
      return
    }
    // A permission/display interruption should not throw away the part that
    // was already collected. The user can still finish or cancel explicitly.
    pauseCapture(message: String(localized: "Capture stopped. Finish to keep the captured content."))
    print("[Shotter] scrolling capture interrupted: \(error.localizedDescription)")
  }

  private func pauseCapture(message: String) {
    state = .interrupted
    recoveryTask?.cancel()
    recoveryTask = nil
    if let scrollMonitor { NSEvent.removeMonitor(scrollMonitor) }
    scrollMonitor = nil
    if let localScrollMonitor { NSEvent.removeMonitor(localScrollMonitor) }
    localScrollMonitor = nil
    screenObserver = nil
    frameProcessor?.stopAcceptingFrames()
    frameProcessor?.refreshPreview()
    let stream = self.stream
    self.stream = nil
    Task { [stream] in try? await stream?.stopCapture() }
    controls?.setStatus(message, height: capturedHeight)
    controls?.finishButton.isEnabled = capturedHeight > 0
  }

  private func clearCallbacks() {
    onComplete = nil
    onCancel = nil
    onError = nil
  }

  private func stopResources() {
    recoveryTask?.cancel()
    recoveryTask = nil
    if let scrollMonitor { NSEvent.removeMonitor(scrollMonitor) }
    scrollMonitor = nil
    if let localScrollMonitor { NSEvent.removeMonitor(localScrollMonitor) }
    localScrollMonitor = nil
    screenObserver = nil
    captureFilter = nil
    captureConfiguration = nil
    snapshotConfiguration = nil
    let processor = frameProcessor
    processor?.stopAcceptingFrames()
    frameProcessor = nil
    let stream = self.stream
    self.stream = nil
    closeWindows()
    Task { [stream, processor] in
      try? await stream?.stopCapture()
      processor?.discard()
    }
  }

  private func observeDisplayChanges() {
    screenObserver = NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
      .receive(on: RunLoop.main)
      .sink { [weak self] _ in
        guard let self, self.state == .starting || self.state == .recording else { return }
        let screen = NSScreen.screens.first { ShotterCoordinateSpace.displayID(for: $0) == self.displayID }
        guard let screen, screen.frame == self.displayFrame,
              screen.backingScaleFactor == self.displayScale else {
          self.interruptOrFail(ShotterScrollCaptureError.displayUnavailable)
          return
        }
      }
  }

  private func didScroll() {
    lastScrollUptime = ProcessInfo.processInfo.systemUptime
    startRecovery()
  }

  private func startRecovery() {
    guard state == .recording, recoveryTask == nil else { return }
    recoveryTask = Task { [weak self] in
      defer { self?.recoveryTask = nil }
      var nextSnapshotUptime: TimeInterval = 0
      var snapshotFailures = 0
      while !Task.isCancelled {
        do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
        guard let self, self.state == .recording, let processor = self.frameProcessor,
          let filter = self.captureFilter, let configuration = self.snapshotConfiguration
        else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let needsRecovery = self.streamFailure != nil || self.capturedHeight == 0 ||
          now - self.lastScrollUptime < 1.25
        guard needsRecovery else { return }
        var snapshotAdvanced = false
        if now >= nextSnapshotUptime, processor.needsSnapshotRecovery() {
          let requestedAtMach = mach_absolute_time()
          do {
            let image = try await SCScreenshotManager.captureImage(
              contentFilter: filter, configuration: configuration)
            guard !Task.isCancelled, self.state == .recording else { return }
            snapshotFailures = 0
            let result = await processor.appendRecoveryImage(image, requestedAt: now, captureTime: requestedAtMach)
            snapshotAdvanced = result?.progress.update == .appended
          } catch {
            snapshotFailures = min(snapshotFailures + 1, 4)
          }
          nextSnapshotUptime = ProcessInfo.processInfo.systemUptime +
            (snapshotFailures == 0 ? 0.25 : Double(snapshotFailures) * 0.5)
        }
        guard !Task.isCancelled, self.state == .recording else { return }
        if (self.streamFailure != nil ||
            ((snapshotAdvanced || self.capturedHeight == 0 || snapshotFailures >= 3) &&
             processor.lastStreamFrameAge() > 0.7)),
          ProcessInfo.processInfo.systemUptime >= self.nextStreamRestartUptime {
          await self.restartStream()
        }
      }
    }
  }

  private func restartStream() async {
    guard !Task.isCancelled, state == .recording,
      let oldStream = stream, let filter = captureFilter,
      let configuration = captureConfiguration, let processor = frameProcessor else { return }
    controls?.setStatus(String(localized: "Capture stalled. Reconnecting…"), height: capturedHeight)
    let replacement = SCStream(filter: filter, configuration: configuration, delegate: processor)
    do {
      try replacement.addStreamOutput(processor, type: .screen,
        sampleHandlerQueue: processor.deliveryQueue)
      processor.setActiveStream(replacement)
      try await replacement.startCapture()
      guard !Task.isCancelled, state == .recording else {
        processor.abandonPendingStream(replacement)
        try? await replacement.stopCapture()
        return
      }
      try processor.commitActiveStream(replacement)
      stream = replacement
      streamFailure = nil
      restartFailures = 0
      nextStreamRestartUptime = ProcessInfo.processInfo.systemUptime + 3
      if let latestProgress { showProgress(latestProgress) }
      Task { try? await oldStream.stopCapture() }
    } catch {
      processor.abandonPendingStream(replacement)
      try? await replacement.stopCapture()
      guard !Task.isCancelled, state == .recording else { return }
      let failure = ShotterScrollFrameProcessor.StreamFailure(
        streamID: ObjectIdentifier(replacement), error: error as NSError)
      guard failure.canRetry else {
        interruptOrFail(error)
        return
      }
      restartFailures += 1
      nextStreamRestartUptime = ProcessInfo.processInfo.systemUptime +
        min(8, pow(2, Double(restartFailures - 1)))
      if streamFailure != nil, restartFailures >= 3 {
        interruptOrFail(error)
      } else if streamFailure == nil, let latestProgress {
        showProgress(latestProgress)
      }
    }
  }

  private func showWindows(around rect: NSRect, on screen: NSScreen) {
    let border = NSPanel(contentRect: rect.insetBy(dx: -3, dy: -3),
                         styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    border.isReleasedWhenClosed = false
    border.isOpaque = false
    border.backgroundColor = .clear
    border.hasShadow = false
    border.ignoresMouseEvents = true
    border.hidesOnDeactivate = false
    border.level = .screenSaver
    border.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    let borderView = NSView(frame: NSRect(origin: .zero, size: border.frame.size))
    borderView.wantsLayer = true
    borderView.layer?.borderColor = NSColor.controlAccentColor.cgColor
    borderView.layer?.borderWidth = 2
    borderView.layer?.cornerRadius = 5
    border.contentView = borderView
    border.orderFrontRegardless()
    self.border = border

    let controls = ShotterScrollControlsPanel(availableSize: NSSize(
      width: screen.visibleFrame.width - 24, height: screen.visibleFrame.height - 24))
    controls.onFinish = { [weak self] in self?.finish() }
    controls.onCancel = { [weak self] in self?.cancel() }
    let area = screen.visibleFrame
    let size = controls.frame.size
    controls.setFrameOrigin(Self.controlsOrigin(size: size, selection: rect, visibleFrame: area))
    controls.orderFrontRegardless()
    self.controls = controls
  }

  static func controlsOrigin(size: NSSize, selection rect: NSRect, visibleFrame area: NSRect) -> NSPoint {
    let minimumX = area.minX + 8
    let maximumX = max(minimumX, area.maxX - size.width - 8)
    let minimumY = area.minY + 8
    let maximumY = max(minimumY, area.maxY - size.height - 8)
    let x = min(max(rect.midX - size.width / 2, minimumX), maximumX)
    let y = min(max(rect.midY - size.height / 2, minimumY), maximumY)
    // Keep the live preview beside the capture. For wide selections, use the
    // space above or below instead; none of these placements intercept scrolls.
    if rect.maxX + 12 <= maximumX {
      return NSPoint(x: rect.maxX + 12, y: y)
    }
    if rect.minX - size.width - 12 >= minimumX {
      return NSPoint(x: rect.minX - size.width - 12, y: y)
    }
    if rect.minY - size.height - 12 >= minimumY {
      return NSPoint(x: x, y: rect.minY - size.height - 12)
    }
    if rect.maxY + 12 <= maximumY {
      return NSPoint(x: x, y: rect.maxY + 12)
    }
    return NSPoint(x: maximumX, y: minimumY)
  }

  private func closeWindows() {
    if let scrollMonitor { NSEvent.removeMonitor(scrollMonitor) }
    scrollMonitor = nil
    let windows = [border, controls].compactMap { $0 }
    border = nil
    controls = nil
    windows.forEach { $0.orderOut(nil) }
    // Keep ARC ownership through AppKit's deferred display/close transaction.
    DispatchQueue.main.async {
      windows.forEach { $0.close() }
      DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        withExtendedLifetime(windows) {}
      }
    }
  }
}

private final class ShotterScrollEventRelay: @unchecked Sendable {
  private let lock = NSLock()
  private var progress: ShotterScrollFrameProcessor.Event?
  private var preview: ShotterScrollFrameProcessor.Event?
  private var failure: ShotterScrollFrameProcessor.Event?
  private var scheduled = false
  private let receive: @MainActor @Sendable (ShotterScrollFrameProcessor.Event) -> Void

  init(receive: @escaping @MainActor @Sendable (ShotterScrollFrameProcessor.Event) -> Void) {
    self.receive = receive
  }

  func send(_ event: ShotterScrollFrameProcessor.Event) {
    let needsDelivery = lock.withLock {
      switch event {
      case .progress: progress = event
      case .preview: preview = event
      case .failure: failure = event
      }
      guard !scheduled else { return false }
      scheduled = true
      return true
    }
    guard needsDelivery else { return }
    DispatchQueue.main.async { [self] in
      let events = lock.withLock {
        let events = [progress, preview, failure].compactMap { $0 }
        progress = nil
        preview = nil
        failure = nil
        scheduled = false
        return events
      }
      events.forEach { receive($0) }
    }
  }
}

@MainActor
private final class ShotterScrollControlsPanel: NSPanel {
  var onFinish: (() -> Void)?
  var onCancel: (() -> Void)?
  let finishButton = ShotterScrollActionButton(title: String(localized: "Finish"), prominent: true)
  private let statusLabel = NSTextField(wrappingLabelWithString: String(localized: "Preparing capture…"))
  private let dimensionsLabel = NSTextField(labelWithString: "")
  private let previewView = NSImageView()
  private let previewPlaceholder = NSTextField(labelWithString: String(localized: "Preparing capture…"))

  init(availableSize: NSSize) {
    let size = NSSize(width: min(280, max(200, availableSize.width)),
                      height: min(480, max(300, availableSize.height)))
    super.init(contentRect: NSRect(origin: .zero, size: size),
               styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    isReleasedWhenClosed = false
    isOpaque = false
    backgroundColor = .clear
    appearance = NSAppearance(named: .darkAqua)
    hasShadow = true
    level = .screenSaver
    animationBehavior = .none
    hidesOnDeactivate = false
    isMovableByWindowBackground = true
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

    let backdrop = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
    backdrop.material = .hudWindow
    backdrop.blendingMode = .behindWindow
    backdrop.state = .active
    backdrop.wantsLayer = true
    backdrop.layer?.cornerRadius = 18
    backdrop.layer?.masksToBounds = true
    contentView = backdrop
    backdrop.addSubview(ShotterScrollSurfaceView(frame: backdrop.bounds))

    let symbol = NSImageView(frame: NSRect(x: 14, y: size.height - 42, width: 28, height: 28))
    symbol.image = NSImage(systemSymbolName: "rectangle.stack", accessibilityDescription: nil)
    symbol.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
    symbol.contentTintColor = .systemCyan
    symbol.wantsLayer = true
    symbol.layer?.backgroundColor = NSColor.systemCyan.withAlphaComponent(0.12).cgColor
    symbol.layer?.cornerRadius = 9
    symbol.layer?.borderWidth = 0.5
    symbol.layer?.borderColor = NSColor.systemCyan.withAlphaComponent(0.25).cgColor
    backdrop.addSubview(symbol)

    let title = NSTextField(labelWithString: String(localized: "Scrolling Screenshot"))
    title.font = .systemFont(ofSize: 12, weight: .semibold)
    title.lineBreakMode = .byTruncatingTail
    title.frame = NSRect(x: 51, y: size.height - 36, width: size.width - 65, height: 18)
    backdrop.addSubview(title)

    let previewFrame = NSRect(x: 14, y: 134, width: size.width - 28, height: size.height - 190)
    let previewBackground = ShotterScrollCanvasView(frame: previewFrame)
    previewBackground.wantsLayer = true
    previewBackground.layer?.cornerRadius = 12
    previewBackground.layer?.masksToBounds = true
    backdrop.addSubview(previewBackground)
    previewView.frame = previewBackground.bounds.insetBy(dx: 10, dy: 10)
    previewView.imageScaling = .scaleProportionallyUpOrDown
    previewView.imageAlignment = .alignCenter
    previewView.setAccessibilityLabel(String(localized: "Scrolling screenshot preview"))
    previewBackground.addSubview(previewView)
    previewPlaceholder.font = .systemFont(ofSize: 11, weight: .medium)
    previewPlaceholder.textColor = .white.withAlphaComponent(0.45)
    previewPlaceholder.alignment = .center
    previewPlaceholder.frame = NSRect(x: 8, y: previewFrame.height / 2 - 9,
                                      width: previewFrame.width - 16, height: 18)
    previewBackground.addSubview(previewPlaceholder)

    let dimensionsBackground = NSView(frame: NSRect(x: 14, y: 106, width: size.width - 28, height: 22))
    dimensionsBackground.wantsLayer = true
    dimensionsBackground.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.045).cgColor
    dimensionsBackground.layer?.cornerRadius = 7
    backdrop.addSubview(dimensionsBackground)
    dimensionsLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .medium)
    dimensionsLabel.alignment = .center
    dimensionsLabel.textColor = .white.withAlphaComponent(0.72)
    dimensionsLabel.frame = dimensionsBackground.bounds.insetBy(dx: 8, dy: 4)
    dimensionsBackground.addSubview(dimensionsLabel)
    statusLabel.font = .systemFont(ofSize: 10.5)
    statusLabel.textColor = .white.withAlphaComponent(0.68)
    statusLabel.maximumNumberOfLines = 3
    statusLabel.frame = NSRect(x: 16, y: 55, width: size.width - 32, height: 43)
    backdrop.addSubview(statusLabel)

    let buttonWidth = (size.width - 36) / 2
    let cancelButton = ShotterScrollActionButton(title: String(localized: "Cancel"), prominent: false)
    cancelButton.target = self
    cancelButton.action = #selector(cancelCapture)
    cancelButton.frame = NSRect(x: 14, y: 14, width: buttonWidth, height: 32)
    backdrop.addSubview(cancelButton)
    finishButton.target = self
    finishButton.action = #selector(finishCapture)
    finishButton.isEnabled = false
    finishButton.frame = NSRect(x: 22 + buttonWidth, y: 14, width: buttonWidth, height: 32)
    backdrop.addSubview(finishButton)
  }

  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }

  func setStatus(_ text: String, height: Int) {
    statusLabel.stringValue = text
  }

  func setCapturedSize(width: Int, height: Int) {
    dimensionsLabel.stringValue = width > 0 && height > 0 ? "\(width) × \(height) px" : ""
  }

  func setPreview(_ image: CGImage) {
    previewView.image = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    previewPlaceholder.isHidden = true
  }

  @objc private func finishCapture() { onFinish?() }
  @objc private func cancelCapture() { onCancel?() }
}

@MainActor
private final class ShotterScrollSurfaceView: NSView {
  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  override func draw(_ dirtyRect: NSRect) {
    let shape = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 18, yRadius: 18)
    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    NSColor.black.withAlphaComponent(0.38).setFill()
    shape.fill()
    NSGradient(colors: [NSColor.systemCyan.withAlphaComponent(0.12),
                        NSColor.systemIndigo.withAlphaComponent(0.04),
                        NSColor.black.withAlphaComponent(0.08)])?.draw(in: bounds, angle: -70)
    NSGraphicsContext.restoreGraphicsState()
    NSColor.white.withAlphaComponent(0.16).setStroke()
    shape.lineWidth = 1
    shape.stroke()
  }
}

@MainActor
private final class ShotterScrollCanvasView: NSView {
  override var mouseDownCanMoveWindow: Bool { true }

  override func draw(_ dirtyRect: NSRect) {
    let shape = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 12, yRadius: 12)
    NSGradient(starting: NSColor.black.withAlphaComponent(0.30),
               ending: NSColor.black.withAlphaComponent(0.16))?.draw(in: shape, angle: -90)
    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    NSColor.white.withAlphaComponent(0.035).setFill()
    for x in stride(from: CGFloat(9), to: bounds.width, by: 14) {
      for y in stride(from: CGFloat(9), to: bounds.height, by: 14) {
        NSBezierPath(ovalIn: NSRect(x: x, y: y, width: 1, height: 1)).fill()
      }
    }
    NSGraphicsContext.restoreGraphicsState()
    NSColor.white.withAlphaComponent(0.08).setStroke()
    shape.lineWidth = 1
    shape.stroke()
  }
}

@MainActor
private final class ShotterScrollActionButton: NSButton {
  private let prominent: Bool

  init(title: String, prominent: Bool) {
    self.prominent = prominent
    super.init(frame: .zero)
    self.title = title
    font = .systemFont(ofSize: 12, weight: .semibold)
    isBordered = false
    setButtonType(.momentaryPushIn)
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override var isEnabled: Bool {
    didSet { needsDisplay = true }
  }

  override func draw(_ dirtyRect: NSRect) {
    let shape = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 9, yRadius: 9)
    if prominent && isEnabled {
      let opacity = isHighlighted ? 0.70 : 0.92
      NSGradient(starting: NSColor.controlAccentColor.withAlphaComponent(opacity),
                 ending: NSColor.systemIndigo.withAlphaComponent(opacity))?.draw(in: shape, angle: -25)
    } else {
      NSColor.white.withAlphaComponent(isHighlighted ? 0.14 : (isEnabled ? 0.08 : 0.04)).setFill()
      shape.fill()
    }
    NSColor.white.withAlphaComponent(isEnabled ? 0.16 : 0.06).setStroke()
    shape.lineWidth = 1
    shape.stroke()
    let attributes: [NSAttributedString.Key: Any] = [
      .font: font ?? NSFont.systemFont(ofSize: 12, weight: .semibold),
      .foregroundColor: NSColor.white.withAlphaComponent(isEnabled ? 0.95 : 0.28)
    ]
    let label = title as NSString
    let labelSize = label.size(withAttributes: attributes)
    label.draw(at: NSPoint(x: (bounds.width - labelSize.width) / 2,
                           y: (bounds.height - labelSize.height) / 2), withAttributes: attributes)
  }
}
