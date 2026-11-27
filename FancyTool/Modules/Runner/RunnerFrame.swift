import SwiftUI

@MainActor
final class RunnerFrame {
  static let shared = RunnerFrame()
  var runner: RunnerModel? { RunnerHandler.shared.getRunnerById(AppState.shared.runnerId) }
  var cache: [CGFloat: [CGImage]] = [:]
  private var recentScale: CGFloat?

  func refresh(for scale: CGFloat) -> [CGImage] {
    defer { recentScale = scale }
    if let cached = cache[scale] { return cached }
    if cache.count >= 2 { cache = cache.filter { $0.key == recentScale } }
    guard let runner, let source = runner.imageSource() else { return [] }
    let pixelHeight = Int(RunnerConfig.baseSize * scale)
    let frames = (0..<min(CGImageSourceGetCount(source), RunnerGIFProcessor.maximumFrames)).compactMap {
      RunnerGIFProcessor.displayFrame(source: source, index: $0, height: pixelHeight,
                                      maximumHeight: pixelHeight, sharp: runner.isDefault && !runner.isPowerStar)
    }
    cache[scale] = frames
    return frames
  }
}
