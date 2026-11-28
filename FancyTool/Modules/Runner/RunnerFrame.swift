import SwiftUI

@MainActor
final class RunnerFrame {
  static let shared = RunnerFrame()
  var runner: RunnerModel? { RunnerHandler.shared.getRunnerById(AppState.shared.runnerId) }
  private var cache: [CGFloat: [CGImage]] = [:]
  private var recentScale: CGFloat?
  private var cachedRunnerID: UUID?
  private var generation: UInt64 = 0
  private let memoryPressure = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)

  private init() {
    memoryPressure.setEventHandler { [weak self] in
      MainActor.assumeIsolated { self?.clear() }
    }
    memoryPressure.resume()
  }

  func clear() {
    generation &+= 1
    cache.removeAll()
    recentScale = nil
    cachedRunnerID = nil
  }

  func refresh(for scale: CGFloat, runner: RunnerModel) async -> [CGImage] {
    if cachedRunnerID != runner.id {
      clear()
      cachedRunnerID = runner.id
    }
    if let cached = cache[scale] {
      recentScale = scale
      return cached
    }
    let version = generation
    let pixelHeight = Int(RunnerConfig.baseSize * scale)
    let frames = await RunnerGIFProcessor.loadFrames(for: runner, height: pixelHeight, maximumHeight: pixelHeight)
    guard !Task.isCancelled else { return [] }
    guard version == generation else { return frames }
    if cache.count >= 2 { cache = cache.filter { $0.key == recentScale } }
    cache[scale] = frames
    recentScale = scale
    return frames
  }
}
