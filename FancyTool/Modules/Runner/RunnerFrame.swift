import SwiftUI

@MainActor
final class RunnerFrame {
  static let shared = RunnerFrame()
  var runner: RunnerModel? { RunnerHandler.shared.getRunnerById(AppState.shared.runnerId) }
  var cache: [CGFloat: [CGImage]] = [:]

  func refresh(for scale: CGFloat) -> [CGImage] {
    if let cached = cache[scale] { return cached }
    cache.removeAll() // Retain only the display's current scale, never original-sized frames.
    guard let runner, let source = runner.imageSource() else { return [] }
    let frames = (0..<min(CGImageSourceGetCount(source), RunnerGIFProcessor.maximumFrames)).compactMap {
      RunnerGIFProcessor.displayFrame(source: source, index: $0, height: Int(RunnerConfig.baseSize * scale))
    }
    cache[scale] = frames
    return frames
  }
}
