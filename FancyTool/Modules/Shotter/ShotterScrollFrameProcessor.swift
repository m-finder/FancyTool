import CoreGraphics
import CoreMedia
import Darwin
import Foundation
import ScreenCaptureKit

final class ShotterScrollFrameProcessor: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
  enum Update: Equatable, Sendable { case appended, unchanged, noOverlap, limitReached }
  struct Progress: Equatable, Sendable {
    let update: Update
    let width: Int
    let height: Int
  }
  enum Event: Sendable {
    case progress(Update, Int, Int, UInt64, Bool)
    case preview(Preview)
    case failure(StreamFailure)
  }

  // CGImage is immutable; only this wrapper crosses back to the main actor.
  struct Preview: @unchecked Sendable { let image: CGImage }

  let deliveryQueue = DispatchQueue(label: "com.wu.FancyTool.scrolling.delivery", qos: .userInitiated,
    target: .global(qos: .userInitiated))
  private let processingQueue = DispatchQueue(label: "com.wu.FancyTool.scrolling.stitching", qos: .userInitiated,
    target: .global(qos: .userInitiated))
  private let lock = NSLock()
  private var isAccepting = true
  private var isBusy = false
  private var pendingSamples = ShotterScrollSampleQueue()
  private var maximumBatchCount = 8
  private var activeStreamID: ObjectIdentifier?
  private var pendingStreamID: ObjectIdentifier?
  private var pendingStreamFailure: StreamFailure?
  private var activeStreamFailure: StreamFailure?
  private var lastStreamFrameUptime: TimeInterval = 0
  private var lastAcceptedCaptureTime: UInt64 = 0
  private var lastAppendMatched = false
  private var lastPublishedProgress: Progress?
  private var lastPublishedMatch = false
  private var stitcher: ShotterScrollStitcher
  private var previewScheduled = false
  private var previewDirty = false
  private var lastPreviewUptime: TimeInterval = 0
  private var lastGrowthUptime: TimeInterval = 0
  private var firstUnmatchedUptime: TimeInterval = 0
  private var consecutiveUnmatchedFrames = 0
  struct StreamFailure: Sendable {
    let streamID: ObjectIdentifier
    let error: NSError

    var canRetry: Bool {
      guard error.domain == SCStreamErrorDomain else { return false }
      switch SCStreamError.Code(rawValue: error.code) {
      case .failedToStart, .failedApplicationConnectionInvalid,
           .failedApplicationConnectionInterrupted, .internalError: return true
      default: return false
      }
    }
  }

  private let receive: @Sendable (Event) -> Void

  init(topInset: Int = 0, bottomInset: Int = 0, receive: @escaping @Sendable (Event) -> Void) {
    stitcher = ShotterScrollStitcher(topInset: topInset, bottomInset: bottomInset)
    self.receive = receive
  }

  func setActiveStream(_ stream: SCStream) {
    lock.withLock {
      pendingStreamID = ObjectIdentifier(stream)
      pendingStreamFailure = nil
    }
  }

  func commitActiveStream(_ stream: SCStream) throws {
    try lock.withLock {
      guard pendingStreamID == ObjectIdentifier(stream), isAccepting else { throw CancellationError() }
      if let pendingStreamFailure { throw pendingStreamFailure.error }
      activeStreamID = ObjectIdentifier(stream)
      activeStreamFailure = nil
      pendingStreamID = nil
      lastStreamFrameUptime = ProcessInfo.processInfo.systemUptime
    }
  }

  func abandonPendingStream(_ stream: SCStream) {
    lock.withLock {
      if pendingStreamID == ObjectIdentifier(stream) {
        pendingStreamID = nil
        pendingStreamFailure = nil
      }
    }
  }

  func isCurrentFailure(_ failure: StreamFailure) -> Bool {
    lock.withLock { activeStreamID == failure.streamID && activeStreamFailure != nil }
  }

  func lastStreamFrameAge() -> TimeInterval {
    lock.withLock { ProcessInfo.processInfo.systemUptime - lastStreamFrameUptime }
  }

  func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
    guard type == .screen, sampleBuffer.isValid,
          let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
          let rawStatus = attachments.first?[.status] as? Int,
          rawStatus == SCFrameStatus.complete.rawValue || rawStatus == SCFrameStatus.started.rawValue ||
            rawStatus == SCFrameStatus.idle.rawValue,
          lock.withLock({ isAccepting &&
            ((activeStreamID == ObjectIdentifier(stream) && activeStreamFailure == nil) ||
             (pendingStreamID == ObjectIdentifier(stream) && pendingStreamFailure == nil)) })
    else { return }
    lock.withLock {
      if activeStreamID == ObjectIdentifier(stream), rawStatus != SCFrameStatus.idle.rawValue {
        lastStreamFrameUptime = ProcessInfo.processInfo.systemUptime
      }
    }
    guard rawStatus != SCFrameStatus.idle.rawValue else { return }
    autoreleasepool {
      let captureTime = (attachments.first?[.displayTime] as? NSNumber)?.uint64Value
        ?? mach_absolute_time()
      guard let sample = ShotterScrollSample(buffer: sampleBuffer, captureTime: captureTime) else { return }
      enqueue(sample)
    }
  }

  private func enqueue(_ sample: ShotterScrollSample) {
    lock.withLock {
      guard isAccepting else { return }
      if isBusy {
        pendingSamples.append(sample)
        return
      }
      isBusy = true
      processingQueue.async { [self, sample] in
        process(sample)
        while let batch = lock.withLock({ () -> [ShotterScrollSample]? in
          guard !pendingSamples.samples.isEmpty else {
            isBusy = false
            return nil
          }
          return Array(pendingSamples.samples.prefix(maximumBatchCount))
        }) {
          var index = batch.count - 1
          var fellBack = false
          let previousHeight = stitcher.pixelHeight
          while !process(batch[index], speculative: index > 0) {
            fellBack = true
            index /= 2
          }
          let consumedCount = index + 1
          let growth = stitcher.pixelHeight - previousHeight
          if growth > 0 {
            let pixelsPerFrame = max(1, (growth + consumedCount - 1) / consumedCount)
            let predictedCount = max(1, min(8, batch[index].image.height / 3 / pixelsPerFrame))
            maximumBatchCount = fellBack ? min(predictedCount, consumedCount) : predictedCount
          } else {
            maximumBatchCount = 1
          }
          lock.withLock { pendingSamples.remove(through: batch[index].captureTime) }
        }
      }
    }
  }

  @discardableResult
  private func process(_ sample: ShotterScrollSample, speculative: Bool = false) -> Bool {
    autoreleasepool {
      guard sample.captureTime > lastAcceptedCaptureTime else { return !speculative }
      let result = stitcher.append(sample.image,
        maximumDisplacement: speculative ? sample.image.height / 3 : nil)
      guard !speculative || result == .appended else { return false }
      let progress = progress(for: result)
      if lastAppendMatched { lastAcceptedCaptureTime = sample.captureTime }
      publishProgress(progress, captureTime: sample.captureTime)
      if progress.update == .appended || previewDirty { schedulePreview() }
      return true
    }
  }

  private func append(_ image: CGImage, suppressTransientMismatch: Bool = true) -> Progress {
    progress(for: stitcher.append(image), suppressTransientMismatch: suppressTransientMismatch)
  }

  private func publishProgress(_ progress: Progress, captureTime: UInt64) {
    guard progress != lastPublishedProgress || lastAppendMatched != lastPublishedMatch else { return }
    lastPublishedProgress = progress
    lastPublishedMatch = lastAppendMatched
    receive(.progress(progress.update, progress.width, progress.height, captureTime, lastAppendMatched))
  }

  private func progress(for result: ShotterScrollStitcher.Update,
    suppressTransientMismatch: Bool = true) -> Progress {
    var update: Update
    switch result {
    case .appended: update = .appended; lastAppendMatched = true
    case .unchanged: update = .unchanged; lastAppendMatched = true
    case .noOverlap: update = .noOverlap; lastAppendMatched = false
    case .limitReached: update = .limitReached; lastAppendMatched = false
    }
    if update == .appended {
      consecutiveUnmatchedFrames = 0
      lock.withLock { lastGrowthUptime = ProcessInfo.processInfo.systemUptime }
    } else if update == .noOverlap {
      if consecutiveUnmatchedFrames == 0 {
        firstUnmatchedUptime = ProcessInfo.processInfo.systemUptime
      }
      consecutiveUnmatchedFrames += 1
      if suppressTransientMismatch && (consecutiveUnmatchedFrames < 3 ||
        ProcessInfo.processInfo.systemUptime - firstUnmatchedUptime < 0.35) {
        update = .unchanged
      }
    } else if update == .unchanged {
      consecutiveUnmatchedFrames = 0
    }
    return Progress(update: update, width: stitcher.pixelWidth, height: stitcher.pixelHeight)
  }

  func needsSnapshotRecovery() -> Bool {
    lock.withLock { isAccepting && !isBusy &&
      ProcessInfo.processInfo.systemUptime - lastGrowthUptime >= 0.15 &&
      ProcessInfo.processInfo.systemUptime - lastStreamFrameUptime >= 0.45 }
  }

  func appendRecoveryImage(_ image: CGImage, requestedAt: TimeInterval,
    captureTime: UInt64) async -> (progress: Progress, matched: Bool)? {
    let snapshot = Preview(image: image)
    return await withCheckedContinuation { continuation in
      processingQueue.async { [self, snapshot] in
        if lock.withLock({ isAccepting && lastGrowthUptime <= requestedAt }) &&
          captureTime > lastAcceptedCaptureTime {
          let progress = autoreleasepool { append(snapshot.image) }
          if lastAppendMatched { lastAcceptedCaptureTime = captureTime }
          publishProgress(progress, captureTime: captureTime)
          if progress.update == .appended || previewDirty { schedulePreview() }
          continuation.resume(returning: (progress, lastAppendMatched))
        } else {
          continuation.resume(returning: nil)
        }
      }
    }
  }

  /// Render at most twenty small thumbnails per second on the processing queue.
  /// A delayed refresh still runs after the last scroll frame, so the preview
  /// cannot remain one update behind when scrolling stops.
  private func schedulePreview() {
    previewDirty = true
    let now = ProcessInfo.processInfo.systemUptime
    let delay = max(0, 0.05 - (now - lastPreviewUptime))
    if delay == 0 {
      // A busy drain can outlive the timer queued behind it. Publish here so
      // preview updates also arrive during continuous scrolling.
      publishPreview()
    } else if !previewScheduled {
      previewScheduled = true
      processingQueue.asyncAfter(deadline: .now() + delay) { [self] in
        previewScheduled = false
        if previewDirty { schedulePreview() }
      }
    }
  }

  private func publishPreview(force: Bool = false) {
    guard force || lock.withLock({ isAccepting }),
          let image = stitcher.makePreview(maximumSize: CGSize(width: 448, height: 480)) else { return }
    lastPreviewUptime = ProcessInfo.processInfo.systemUptime
    previewDirty = false
    receive(.preview(Preview(image: image)))
  }

  func stream(_ stream: SCStream, didStopWithError error: Error) {
    let failure = StreamFailure(streamID: ObjectIdentifier(stream), error: error as NSError)
    let shouldDeliver = lock.withLock {
      guard isAccepting else { return false }
      if pendingStreamID == failure.streamID {
        pendingStreamFailure = failure
        return false
      }
      guard activeStreamID == failure.streamID, activeStreamFailure == nil else { return false }
      activeStreamFailure = failure
      lastStreamFrameUptime = 0
      return true
    }
    if shouldDeliver { receive(.failure(failure)) }
  }

  func stopAcceptingFrames() {
    lock.withLock {
      isAccepting = false
      pendingSamples.removeAll()
    }
  }

  func finishPendingFrames() async {
    await withCheckedContinuation { continuation in
      deliveryQueue.async { [self] in
        lock.withLock { isAccepting = false }
        processingQueue.async { continuation.resume() }
      }
    }
  }
  func refreshPreview() { processingQueue.async { [self] in publishPreview(force: true) } }

  func appendFinalImage(_ image: CGImage) async -> Progress {
    let snapshot = Preview(image: image)
    return await withCheckedContinuation { continuation in
      processingQueue.async { [self, snapshot] in
        let progress = autoreleasepool { append(snapshot.image, suppressTransientMismatch: false) }
        publishPreview(force: true)
        continuation.resume(returning: progress)
      }
    }
  }

  func makeImage() async -> CGImage? {
    await withCheckedContinuation { continuation in
      processingQueue.async { [self] in
        publishPreview(force: true)
        let image = autoreleasepool { stitcher.makeImage() }
        stitcher = ShotterScrollStitcher()
        continuation.resume(returning: image)
      }
    }
  }

  func discard() {
    processingQueue.async { [self] in stitcher = ShotterScrollStitcher() }
  }
}


struct ShotterScrollSample: @unchecked Sendable {
  let image: CGImage
  let captureTime: UInt64

  init(image: CGImage, captureTime: UInt64) {
    self.image = image
    self.captureTime = captureTime
  }

  init?(buffer: CMSampleBuffer, captureTime: UInt64) {
    guard let pixels = buffer.imageBuffer,
          CVPixelBufferGetPixelFormatType(pixels) == kCVPixelFormatType_32BGRA,
          CVPixelBufferLockBaseAddress(pixels, .readOnly) == kCVReturnSuccess else { return nil }
    defer { CVPixelBufferUnlockBaseAddress(pixels, .readOnly) }
    let width = CVPixelBufferGetWidth(pixels)
    let height = CVPixelBufferGetHeight(pixels)
    let rowBytes = CVPixelBufferGetBytesPerRow(pixels)
    guard width > 0, height > 0, width <= 40_000_000 / height,
          rowBytes >= width * 4, rowBytes <= Int.max / height,
          let baseAddress = CVPixelBufferGetBaseAddress(pixels) else { return nil }
    let data = Data(bytes: baseAddress, count: rowBytes * height)
    guard let provider = CGDataProvider(data: data as CFData),
          let image = CGImage(width: width, height: height,
                              bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: rowBytes,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!,
                              bitmapInfo: CGBitmapInfo.byteOrder32Little.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)),
                              provider: provider, decode: nil, shouldInterpolate: false,
                              intent: .defaultIntent) else { return nil }
    self.image = image
    self.captureTime = captureTime
  }
}

struct ShotterScrollSampleQueue {
  private(set) var samples: [ShotterScrollSample] = []
  private(set) var byteCount = 0
  private let maximumBytes: Int
  private let maximumCount: Int

  init(maximumBytes: Int = 48 * 1024 * 1024, maximumCount: Int = 8) {
    self.maximumBytes = max(1, maximumBytes)
    self.maximumCount = max(1, maximumCount)
  }

  mutating func append(_ sample: ShotterScrollSample) {
    if let last = samples.last, sample.captureTime <= last.captureTime { return }
    samples.append(sample)
    byteCount += sample.image.bytesPerRow * sample.image.height
    while samples.count > 1 && (samples.count > maximumCount || byteCount > maximumBytes) {
      let index = samples.count > 2 ? (1..<(samples.count - 1)).min {
        samples[$0 + 1].captureTime - samples[$0 - 1].captureTime <
          samples[$1 + 1].captureTime - samples[$1 - 1].captureTime
      }! : 0
      byteCount -= samples[index].image.bytesPerRow * samples[index].image.height
      samples.remove(at: index)
    }
  }

  mutating func remove(through captureTime: UInt64) {
    let count = samples.prefix { $0.captureTime <= captureTime }.count
    for sample in samples.prefix(count) {
      byteCount -= sample.image.bytesPerRow * sample.image.height
    }
    samples.removeFirst(count)
  }

  mutating func removeAll() {
    samples.removeAll(keepingCapacity: true)
    byteCount = 0
  }
}

enum ShotterScrollContentFilter {
  static func make(display: SCDisplay, application: SCRunningApplication,
    windows: [SCWindow], excludingWindowIDs: Set<CGWindowID>) -> SCContentFilter {
    let sourceWindows = windows.filter {
      $0.owningApplication?.processID == application.processID && !excludingWindowIDs.contains($0.windowID)
    }
    return SCContentFilter(display: display, excludingApplications: [application],
      exceptingWindows: sourceWindows)
  }
}

struct ShotterScrollCaptureRegion {
  let sourceRect: CGRect
  let width: Int
  let height: Int
  let topInset: Int
  let bottomInset: Int

  init(selection: CGRect, bounds: CGRect, scale: CGFloat) {
    let contextHeight = min(bounds.height, max(selection.height, 600))
    let y = min(max(bounds.minY, selection.midY - contextHeight / 2), bounds.maxY - contextHeight)
    let top = (y * scale).rounded(.down) / scale
    let bottom = min(bounds.maxY, ((y + contextHeight) * scale).rounded(.up) / scale)
    sourceRect = CGRect(x: selection.minX, y: top, width: selection.width, height: bottom - top)
    width = max(1, Int((selection.width * scale).rounded(.up)))
    height = max(1, Int((sourceRect.height * scale).rounded()))
    topInset = max(0, Int(((selection.minY - top) * scale).rounded()))
    bottomInset = max(0, height - topInset - Int((selection.height * scale).rounded(.up)))
  }
}
