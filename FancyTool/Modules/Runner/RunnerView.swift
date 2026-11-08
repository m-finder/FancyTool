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
  
  private struct Playback: Equatable {
    let runnerID: UUID?
    let interval: Float
    let isRunning: Bool
    let isWindowVisible: Bool
  }

  var body: some View {
    VStack {
      
      if let runner = runner {
        
        Image(
          runner.getImage(imageIndex),
          scale: 1,
          label: Text("")
        )
        .interpolation(.high)
        .resizable()
        .aspectRatio(contentMode: .fit)
        
      } else {
        Image("default").resizable().aspectRatio(contentMode: .fit).scaledToFit()
      }
      
    }
    .background {
      if isRunning {
        RunnerPreviewVisibility(isVisible: $isWindowVisible)
      }
    }
    .task(id: Playback(runnerID: runner?.id, interval: factor, isRunning: isRunning,
                       isWindowVisible: isWindowVisible)) {
      // Static thumbnails do not need a clock; SwiftUI cancels playback when
      // the preview disappears or a different runner is selected.
      guard isRunning, isWindowVisible, factor.isFinite, factor > 0,
            let count = runner?.frameNumber, count > 1 else { return }
      while !Task.isCancelled {
        do { try await Task.sleep(for: .seconds(Double(factor))) }
        catch { return }
        guard !Task.isCancelled else { return }
        if imageIndex == 0 { direction = 1 }
        if imageIndex >= count - 1 {
          if autoReverse { direction = -1 }
          else { direction = 1; imageIndex = 0 }
        }
        imageIndex += direction
      }
    }
    .onChange(of: runner) {
      imageIndex = 0
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

