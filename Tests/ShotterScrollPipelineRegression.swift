import CoreGraphics
import CoreMedia
import Foundation
import ScreenCaptureKit

private final class Events: @unchecked Sendable {
  private let lock = NSLock()
  private var events: [ShotterScrollFrameProcessor.Event] = []
  func append(_ event: ShotterScrollFrameProcessor.Event) { lock.withLock { events.append(event) } }
  var failures: [ShotterScrollFrameProcessor.StreamFailure] {
    lock.withLock { events.compactMap { if case let .failure(failure) = $0 { failure } else { nil } } }
  }
  var progressCount: Int {
    lock.withLock { events.filter { if case .progress = $0 { true } else { false } }.count }
  }
}

@main
struct ShotterScrollPipelineRegression {
  static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
  }

  static func document(width: Int = 320, height: Int = 2400) -> CGImage {
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
      bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let bytes = context.data!.assumingMemoryBound(to: UInt8.self)
    var seed: UInt64 = 42
    for y in 0..<height {
      for x in 0..<width {
        seed = seed &* 6364136223846793005 &+ 1
        let offset = (y * width + x) * 4
        bytes[offset] = UInt8(truncatingIfNeeded: seed >> 32)
        bytes[offset + 1] = UInt8(truncatingIfNeeded: seed >> 40)
        bytes[offset + 2] = UInt8(truncatingIfNeeded: seed >> 48)
        bytes[offset + 3] = 255
      }
    }
    return context.makeImage()!
  }

  static func stream() -> SCStream {
    SCStream(filter: SCContentFilter(), configuration: SCStreamConfiguration(), delegate: nil)
  }

  static func queueBounds() {
    let image = document(width: 64, height: 64)
    let bytes = image.bytesPerRow * image.height
    var queue = ShotterScrollSampleQueue(maximumBytes: bytes * 4, maximumCount: 6)
    for time in 1...10_000 {
      queue.append(ShotterScrollSample(image: image, captureTime: UInt64(time)))
      require(queue.samples.count <= 4 && queue.byteCount <= bytes * 4, "Frame backlog exceeded its budget")
      require(queue.samples.first?.captureTime == 1, "Lost the nearest overlap anchor")
      require(queue.samples.last?.captureTime == UInt64(time), "Dropped the newest frame")
      let times = queue.samples.map(\.captureTime)
      require(zip(times, times.dropFirst()).allSatisfy { $0 < $1 }, "Frame order changed")
    }
    let retained = queue.samples.map(\.captureTime)
    queue.append(ShotterScrollSample(image: image, captureTime: 9999))
    require(queue.samples.map(\.captureTime) == retained, "Out-of-order frame was accepted")
    queue.remove(through: retained[1])
    require(queue.samples.map(\.captureTime) == Array(retained.dropFirst(2)), "Batch removal lost a new frame")
    queue.removeAll()
    require(queue.samples.isEmpty && queue.byteCount == 0, "Cancelled capture retained queued frames")
    var large = ShotterScrollSampleQueue(maximumBytes: bytes / 2)
    for time in 1...10 { large.append(ShotterScrollSample(image: image, captureTime: UInt64(time))) }
    require(large.samples.count == 1 && large.samples.first?.captureTime == 10, "Oversized frame queue is unbounded")
    print("PASS bounded backlog: 10,000 frames, ordered anchors, cancellation")
  }

  static func recovery() async throws {
    let events = Events()
    let processor = ShotterScrollFrameProcessor { events.append($0) }
    let first = stream()
    processor.setActiveStream(first)
    try processor.commitActiveStream(first)
    let source = document()
    func frame(_ offset: Int) -> CGImage {
      source.cropping(to: CGRect(x: 0, y: offset, width: source.width, height: 400))!
    }
    let initial = await processor.appendRecoveryImage(frame(0), requestedAt: .greatestFiniteMagnitude, captureTime: 1)
    require(initial?.progress.height == 400, "Initial frame")
    let error = NSError(domain: SCStreamErrorDomain,
      code: SCStreamError.Code.failedApplicationConnectionInterrupted.rawValue)
    processor.stream(first, didStopWithError: error)
    require(events.failures.count == 1 && events.failures[0].canRetry, "Transient failure must be recoverable")
    processor.stream(first, didStopWithError: error)
    require(events.failures.count == 1, "Duplicate stop callback scheduled another recovery")
    let recovered = await processor.appendRecoveryImage(frame(80), requestedAt: .greatestFiniteMagnitude, captureTime: 2)
    require(recovered?.progress.height == 480, "Stream interruption disabled snapshot recovery")

    let failedReplacement = stream()
    processor.setActiveStream(failedReplacement)
    processor.stream(failedReplacement, didStopWithError: error)
    do {
      try processor.commitActiveStream(failedReplacement)
      preconditionFailure("A replacement that stopped during startup was committed")
    } catch {}
    processor.abandonPendingStream(failedReplacement)
    require(processor.isCurrentFailure(events.failures[0]), "Failed replacement lost the active failure")

    let replacement = stream()
    processor.setActiveStream(replacement)
    try processor.commitActiveStream(replacement)
    require(!processor.isCurrentFailure(events.failures[0]), "Stale stream failure interrupts the replacement")
    processor.stream(first, didStopWithError: error)
    require(events.failures.count == 1, "Retired stream sent a new failure")
    let continued = await processor.appendRecoveryImage(frame(160), requestedAt: .greatestFiniteMagnitude, captureTime: 3)
    require(continued?.progress.height == 560, "Reconnection reset the stitched content")
    let stale = await processor.appendRecoveryImage(frame(80), requestedAt: .greatestFiniteMagnitude, captureTime: 2)
    require(stale == nil, "Stale snapshot replaced newer content")
    await processor.finishPendingFrames()
    let late = await processor.appendRecoveryImage(frame(240), requestedAt: .greatestFiniteMagnitude, captureTime: 4)
    require(late == nil, "Finishing accepted a late recovery frame")
    let result = await processor.makeImage()
    require(result?.height == 560, "Finishing lost the recovered content")

    for code in [SCStreamError.Code.userStopped, .userDeclined, .missingEntitlements, .noCaptureSource] {
      let failure = ShotterScrollFrameProcessor.StreamFailure(streamID: ObjectIdentifier(first),
        error: NSError(domain: SCStreamErrorDomain, code: code.rawValue))
      require(!failure.canRetry, "Permanent failure was retried")
    }
    print("PASS transient failure, startup race, stale callbacks, recovery ordering, finish")
  }

  static func previews() {
    let source = document(width: 320, height: 20_000)
    var stitcher = ShotterScrollStitcher()
    for offset in stride(from: 0, through: 19_200, by: 240) {
      let frame = source.cropping(to: CGRect(x: 0, y: offset, width: 320, height: 800))!
      require(stitcher.append(frame) == .appended, "Long preview input did not stitch")
    }
    let start = ProcessInfo.processInfo.systemUptime
    for _ in 0..<30 {
      let preview = stitcher.makePreview(maximumSize: CGSize(width: 448, height: 480))!
      require(preview.width <= 448 && preview.height <= 480, "Preview exceeded its size budget")
      let data = preview.dataProvider!.data!
      let pixels = CFDataGetBytePtr(data)!
      for y in 0..<preview.height {
        require(pixels[y * preview.bytesPerRow + preview.width / 2 * 4 + 3] == 255,
          "A gap appeared between scaled strips")
      }
    }
    let milliseconds = (ProcessInfo.processInfo.systemUptime - start) * 1000 / 30
    print(String(format: "PASS 20,000-row preview: bounded size, no strip gaps, %.2f ms/frame", milliseconds))
  }

  static func captureRegions() async {
    let bounds = CGRect(x: 0, y: 0, width: 1440, height: 900)
    for scale in [CGFloat(1), 2] {
      for selection in [CGRect(x: 200, y: 0, width: 320, height: 80),
        CGRect(x: 200, y: 360, width: 320, height: 120),
        CGRect(x: 200, y: 820, width: 320, height: 80),
        CGRect(x: 200, y: 100, width: 320, height: 700)] {
        let region = ShotterScrollCaptureRegion(selection: selection, bounds: bounds, scale: scale)
        require(bounds.contains(region.sourceRect) && region.sourceRect.contains(selection),
          "Matching context escaped the display or lost the selection")
        require(region.sourceRect.minX == selection.minX && region.sourceRect.width == selection.width,
          "Matching context changed the selected columns")
        require(region.height <= Int(max(600, selection.height) * scale), "Matching context is unbounded")
        require(region.height - region.topInset - region.bottomInset == Int(selection.height * scale),
          "Context changed the output viewport height")
      }
    }
    let source = document(width: 320, height: 2400)
    let context = CGContext(data: nil, width: source.width, height: source.height, bitsPerComponent: 8,
      bytesPerRow: source.width * 4, space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.draw(source, in: CGRect(x: 0, y: 0, width: source.width, height: source.height))
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: source.height - 500, width: source.width, height: 260))
    let document = context.makeImage()!
    let processor = ShotterScrollFrameProcessor(topInset: 260, bottomInset: 260) { _ in }
    var timestamp: UInt64 = 1
    for offset in [0, 0, 20, 60, 60, 130, 210, 190, 210, 280, 400, 520, 680, 850, 1000] {
      let frame = document.cropping(to: CGRect(x: 0, y: offset, width: 320, height: 600))!
      _ = await processor.appendRecoveryImage(frame, requestedAt: .greatestFiniteMagnitude, captureTime: timestamp)
      timestamp += 1
    }
    await processor.finishPendingFrames()
    let result = await processor.makeImage()!
    let expected = document.cropping(to: CGRect(x: 0, y: 260, width: 320, height: 1080))!
    require(result.width == expected.width && result.height == expected.height,
      "Sparse selection stalled or exported its matching context")
    func bytes(_ image: CGImage) -> Data {
      let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
        bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
      context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
      return Data(bytes: context.data!, count: context.bytesPerRow * context.height)
    }
    require(bytes(result) == bytes(expected), "Context capture omitted, repeated, or exposed extra rows")
    for insets in [(0, 520), (260, 260), (520, 0)] {
      var stitcher = ShotterScrollStitcher(topInset: insets.0, bottomInset: insets.1)
      _ = stitcher.append(document.cropping(to: CGRect(x: 0, y: 0, width: 320, height: 600))!)
      let preview = stitcher.makePreview(maximumSize: CGSize(width: 448, height: 480))!
      let selected = document.cropping(to: CGRect(x: 0, y: insets.0, width: 320, height: 80))!
      require(bytes(preview) == bytes(selected), "Preview includes pixels outside the selection")
    }
    print("PASS small selection: bounded context, pauses, reverse, exact output and preview crop")
  }

  static func delivery() async throws {
    let processor = ShotterScrollFrameProcessor { _ in }
    let active = stream()
    processor.setActiveStream(active)
    try processor.commitActiveStream(active)
    let source = document()
    for index in 0...100 {
      autoreleasepool {
        let frame = source.cropping(to: CGRect(x: 0, y: index * 4, width: source.width, height: 800))!
        var pixels: CVPixelBuffer?
        require(CVPixelBufferCreate(nil, frame.width, frame.height, kCVPixelFormatType_32BGRA,
          nil, &pixels) == kCVReturnSuccess, "Pixel buffer creation")
        let buffer = pixels!
        CVPixelBufferLockBaseAddress(buffer, [])
        let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: frame.width,
          height: frame.height, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue |
            CGImageAlphaInfo.premultipliedFirst.rawValue)!
        context.draw(frame, in: CGRect(x: 0, y: 0, width: frame.width, height: frame.height))
        CVPixelBufferUnlockBaseAddress(buffer, [])
        var format: CMVideoFormatDescription?
        require(CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: buffer,
          formatDescriptionOut: &format) == noErr, "Sample format")
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 30),
          presentationTimeStamp: CMTime(value: Int64(index), timescale: 30), decodeTimeStamp: .invalid)
        var sample: CMSampleBuffer?
        require(CMSampleBufferCreateReadyWithImageBuffer(allocator: nil, imageBuffer: buffer,
          formatDescription: format!, sampleTiming: &timing, sampleBufferOut: &sample) == noErr, "Sample buffer")
        let attachments = CMSampleBufferGetSampleAttachmentsArray(sample!, createIfNecessary: true)!
          as! [NSMutableDictionary]
        attachments[0][SCStreamFrameInfo.status.rawValue] = SCFrameStatus.complete.rawValue
        attachments[0][SCStreamFrameInfo.displayTime.rawValue] = NSNumber(value: index + 1)
        processor.stream(active, didOutputSampleBuffer: sample!, of: .screen)
      }
    }
    await processor.finishPendingFrames()
    let result = await processor.makeImage()
    require(result?.height == 1200, "Burst delivery lost the last viewport")
    let expected = source.cropping(to: CGRect(x: 0, y: 0, width: source.width, height: 1200))!
    func renderedBytes(_ image: CGImage) -> Data {
      let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
        bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
      context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
      return Data(bytes: context.data!, count: context.bytesPerRow * context.height)
    }
    require(renderedBytes(result!) == renderedBytes(expected), "Burst delivery introduced missing or repeated rows")
    print("PASS 101-frame delivery burst: bounded processing, exact final image, final-frame drain")
  }

  static func unchangedProgress() async {
    let events = Events()
    let processor = ShotterScrollFrameProcessor { events.append($0) }
    let source = document()
    let first = source.cropping(to: CGRect(x: 0, y: 0, width: 320, height: 400))!
    for time in 1...101 {
      let result = await processor.appendRecoveryImage(first, requestedAt: .greatestFiniteMagnitude,
        captureTime: UInt64(time))
      require(result?.matched == true, "Deduplication stopped frame matching")
    }
    require(events.progressCount == 2, "Unchanged frames keep waking the main actor")
    let next = source.cropping(to: CGRect(x: 0, y: 80, width: 320, height: 400))!
    let result = await processor.appendRecoveryImage(next, requestedAt: .greatestFiniteMagnitude, captureTime: 102)
    require(result?.progress.height == 480 && events.progressCount == 3,
      "Scrolling after idle must publish its new height")
    await processor.finishPendingFrames()
    print("PASS 100 unchanged frames: one status transition, scrolling resumes immediately")
  }

  static func main() async throws {
    queueBounds()
    try await recovery()
    try await delivery()
    await unchangedProgress()
    await captureRegions()
    previews()
  }
}
