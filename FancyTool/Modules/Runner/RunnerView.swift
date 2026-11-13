//
//  RunnerView.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/1.
//
import SwiftUI
import Combine

struct RunnerView: View {
  
  var runner: RunnerModel?
  var factor: Float
  var autoReverse = false
  var isRunning: Bool = false
  
  @State private var direction = 1
  @State private var imageIndex = 0
  @State private var isWindowVisible = false
  @State private var frames: [CGImage] = []

  private struct FrameLoad: Equatable {
    let runnerID: UUID?
    let isRunning: Bool
  }
  
  private struct Playback: Equatable {
    let runnerID: UUID?
    let interval: Float
    let isRunning: Bool
    let isWindowVisible: Bool
    let frameCount: Int
  }

  var body: some View {
    VStack {
      
      if !frames.isEmpty {
        Image(decorative: frames[min(imageIndex, frames.count - 1)], scale: 1)
          .interpolation(runner?.isPowerStar == true ? .medium : runner?.isDefault == true ? .none : .high)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .accessibilityLabel(Text(""))
      } else {
        Image("default").resizable().aspectRatio(contentMode: .fit).scaledToFit()
      }
      
    }
    .background {
      if isRunning {
        RunnerPreviewVisibility(isVisible: $isWindowVisible)
      }
    }
    .task(id: FrameLoad(runnerID: runner?.id, isRunning: isRunning)) {
      guard let runner else {
        frames = []
        return
      }
      let frameCount = isRunning ? min(runner.frameNumber, RunnerGIFProcessor.maximumFrames) : 1
      let previewIndex = runner.isDefault ? min(max(0, runner.frameNumber - 1), runner.frameNumber / 3) : 0
      let loadedFrames = await Task.detached(priority: .utility) {
        guard let source = runner.imageSource() else { return [CGImage]() }
        return (0..<frameCount).compactMap {
          RunnerGIFProcessor.displayFrame(source: source, index: isRunning ? $0 : previewIndex,
                                          height: RunnerGIFProcessor.displayHeight,
                                          sharp: runner.isDefault && !runner.isPowerStar)
        }
      }.value
      guard !Task.isCancelled else { return }
      frames = loadedFrames
      imageIndex = 0
      direction = 1
    }
    .task(id: Playback(runnerID: runner?.id, interval: factor, isRunning: isRunning,
                       isWindowVisible: isWindowVisible, frameCount: frames.count)) {
      // Static thumbnails do not need a clock; SwiftUI cancels playback when
      // the preview disappears or a different runner is selected.
      guard isRunning, isWindowVisible, factor.isFinite, factor > 0,
            frames.count > 1 else { return }
      let count = frames.count
      while !Task.isCancelled {
        do { try await Task.sleep(for: .seconds(Double(factor))) }
        catch { return }
        guard !Task.isCancelled else { return }
        if autoReverse {
          if imageIndex >= count - 1 { direction = -1 }
          else if imageIndex <= 0 { direction = 1 }
          imageIndex += direction
        } else if imageIndex >= count - 1 {
          imageIndex = 0
        } else {
          imageIndex += 1
        }
      }
    }
    .onChange(of: runner) {
      imageIndex = 0
      direction = 1
    }
    
  }
}

private struct RunnerPreviewVisibility: NSViewRepresentable {
  @Binding var isVisible: Bool

  func makeNSView(context: Context) -> VisibilityView {
    let view = VisibilityView()
    view.onChange = { isVisible = $0 }
    return view
  }

  func updateNSView(_ nsView: VisibilityView, context: Context) {
    nsView.onChange = { isVisible = $0 }
  }

  static func dismantleNSView(_ nsView: VisibilityView, coordinator: ()) {
    nsView.stopObserving()
  }

  final class VisibilityView: NSView {
    var onChange: ((Bool) -> Void)?
    private var observations = Set<AnyCancellable>()
    private var lastVisibility: Bool?

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      observations.removeAll()
      if let window {
        let center = NotificationCenter.default
        center.publisher(for: NSWindow.didChangeOcclusionStateNotification, object: window)
          .merge(with: center.publisher(for: NSWindow.didMiniaturizeNotification, object: window),
                 center.publisher(for: NSWindow.didDeminiaturizeNotification, object: window))
          .sink { [weak self] _ in self?.publishVisibility() }
          .store(in: &observations)
        center.publisher(for: NSWindow.willCloseNotification, object: window)
          .sink { [weak self] _ in self?.publishVisibility(false) }
          .store(in: &observations)
      }
      publishVisibility()
    }

    func stopObserving() {
      observations.removeAll()
      publishVisibility(false)
      onChange = nil
    }

    private func publishVisibility(_ forced: Bool? = nil) {
      let visible = forced ?? window.map { $0.isVisible && $0.occlusionState.contains(.visible) } ?? false
      guard visible != lastVisibility else { return }
      lastVisibility = visible
      // Window attachment can occur during a SwiftUI view update.
      let onChange = onChange
      DispatchQueue.main.async { onChange?(visible) }
    }
  }
}

