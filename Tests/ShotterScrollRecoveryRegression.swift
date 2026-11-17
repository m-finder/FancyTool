private extension ShotterScrollCaptureController {
  static func checkRecoveryLifetime() async throws {
    let controller = ShotterScrollCaptureController()
    let processor = ShotterScrollFrameProcessor { _ in }
    let stream = SCStream(filter: SCContentFilter(), configuration: SCStreamConfiguration(), delegate: processor)
    processor.setActiveStream(stream)
    try processor.commitActiveStream(stream)
    controller.state = .recording
    controller.capturedHeight = 400
    controller.frameProcessor = processor
    controller.captureFilter = SCContentFilter()
    controller.snapshotConfiguration = SCStreamConfiguration()
    controller.startRecovery()
    try await Task.sleep(for: .milliseconds(260))
    precondition(controller.recoveryTask == nil, "Idle capture kept its polling task")
    controller.didScroll()
    precondition(controller.recoveryTask != nil, "Scrolling did not restart recovery")
    for _ in 0..<100 { controller.didScroll() }
    controller.lastScrollUptime -= 2
    try await Task.sleep(for: .milliseconds(260))
    precondition(controller.recoveryTask == nil, "Pausing did not stop recovery")
    let error = NSError(domain: SCStreamErrorDomain,
      code: SCStreamError.Code.failedApplicationConnectionInterrupted.rawValue)
    processor.stream(stream, didStopWithError: error)
    controller.receive(.failure(.init(streamID: ObjectIdentifier(stream), error: error)))
    precondition(controller.recoveryTask != nil, "An idle stream failure did not restart recovery")
    controller.cancel()
    try await Task.sleep(for: .milliseconds(20))
    precondition(controller.recoveryTask == nil, "Cancellation left recovery running")
    controller.didScroll()
    precondition(controller.recoveryTask == nil, "Stopped capture restarted recovery")
    print("PASS recovery stops when idle, resumes on scroll/failure, and stays stopped after cancellation")
  }
}

@main
struct ShotterScrollRecoveryRegression {
  @MainActor
  static func main() async throws {
    try await ShotterScrollCaptureController.checkRecoveryLifetime()
  }
}
