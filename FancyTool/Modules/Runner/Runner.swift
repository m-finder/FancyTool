import AppKit
import Combine

@MainActor
final class Runner: NSObject, CAAnimationDelegate {
  static let shared = Runner()

  private let item: NSStatusItem = {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    item.autosaveName = "FancyTool.Runner"
    return item
  }()
  var statusButton: NSStatusBarButton? { item.button }
  private var cancellables = Set<AnyCancellable>()
  private weak var observedWindow: NSWindow?
  private var windowObservation: AnyCancellable?
  private var renderedScale: CGFloat = 0
  private var cpuUsage = 0.0
  private var smoothedCPU = 0.0
  private var lastCPUSample: UInt64?
  private var isCharging = false
  private var displaySleeping = false
  private var lowPowerEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
  private var reduceMotionEnabled = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
  private var companionBehavior = RunnerCompanionBehavior()
  private var renderedState: RunnerCompanionState?
  private var activityClock: AnyCancellable?
  private var activityInterval: TimeInterval?
  private var companionTime: TimeInterval = 0
  private var lastCompanionTick = ProcessInfo.processInfo.systemUptime
  private var companionRate = 1.0
  private var renderedSince: TimeInterval = 0
  private var transitionSprites: [RunnerCompanionArt.Sprite] = []
  private var companionAnimationGeneration: UInt64 = 0
  private var reactionGate = CompanionReactionGate()

  private var currentScale: CGFloat {
    item.button?.window?.screen?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
  }

  private var shouldPause: Bool {
    displaySleeping || lowPowerEnabled || reduceMotionEnabled
  }

  private var companionPaused: Bool {
    displaySleeping || reduceMotionEnabled
  }

  private var targetCompanionRate: Double {
    RunnerCompanionPlayback.rate(cpu: smoothedCPU, lowPower: lowPowerEnabled)
  }

  private var companionNeedsActivityClock: Bool {
    guard let renderedState else { return false }
    return renderedState != .idle && renderedState != .busy && renderedState != .sleeping
  }

  func mount() {
    guard let button = item.button else { return }
    RunnerLayer.shared.mount(button: button, scale: currentScale)
    observe()
    reload()
  }

  func change() {
    RunnerFrame.shared.cache.removeAll()
    reload()
  }

  private func reload() {
    companionAnimationGeneration &+= 1
    renderedScale = currentScale
    observeStatusWindow()
    renderedState = nil
    transitionSprites = []
    companionBehavior = RunnerCompanionBehavior()
    companionTime = 0
    lastCompanionTick = ProcessInfo.processInfo.systemUptime
    companionRate = companionPaused ? 0 : targetCompanionRate
    synchronizeActivityClock()
    if AppState.shared.runnerCompanion {
      item.menu = nil
      item.button?.target = self
      item.button?.action = #selector(companionClicked)
      item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
      setWidth(RunnerCompanionArt.size.width)
      refreshBehavior()
      return
    }

    item.button?.target = nil
    item.button?.action = nil
    item.menu = AppMenu.shared.getMenus()
    item.button?.toolTip = nil
    let frames = RunnerFrame.shared.refresh(for: currentScale)
    guard let first = frames.first else {
      RunnerLayer.shared.unmount()
      setWidth(RunnerConfig.defaultIconSize)
      item.button?.image = NSImage(named: RunnerConfig.defaultIconName)?.resized(to: RunnerConfig.defaultIconSize)
      return
    }
    setWidth(RunnerConfig.baseSize * CGFloat(first.width) / CGFloat(first.height))
    installAnimation(frames: frames, frameDuration: 1 / RunnerConfig.minFPS)
    refreshBehavior()
  }

  private func setWidth(_ width: CGFloat) {
    item.length = width
    item.button?.frame.size.width = width
    let bounds = item.button?.bounds ?? .zero
    RunnerLayer.shared.layer?.frame = AppState.shared.runnerCompanion
      ? bounds.insetBy(dx: (bounds.width - RunnerCompanionArt.size.width) / 2, dy: 0)
      : bounds
  }

  private func installAnimation(frames: [CGImage], frameDuration: TimeInterval) {
    guard let layer = RunnerLayer.shared.layer, let first = frames.first else { return }
    item.button?.image = nil
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    layer.removeAllAnimations()
    layer.speed = 1
    layer.timeOffset = 0
    layer.beginTime = 0
    layer.contentsScale = currentScale
    layer.magnificationFilter = .linear
    layer.minificationFilter = .linear
    layer.contents = first
    layer.isHidden = false
    layer.frame = item.button?.bounds ?? .zero
    let animation = CAKeyframeAnimation(keyPath: "contents")
    animation.values = frames
    animation.keyTimes = frames.indices.map { NSNumber(value: Double($0) / Double(frames.count)) }
    animation.duration = Double(frames.count) * frameDuration
    animation.repeatCount = .infinity
    animation.calculationMode = .discrete
    layer.add(animation, forKey: "runner")
    CATransaction.commit()
  }

  private func refreshBehavior() {
    if AppState.shared.runnerCompanion {
      let now = ProcessInfo.processInfo.systemUptime
      let elapsed = max(0, now - lastCompanionTick)
      companionTime += elapsed * companionRate
      lastCompanionTick = now
      if companionPaused {
        companionRate = 0
      } else if companionRate == 0 {
        companionRate = targetCompanionRate
      } else {
        companionRate = RunnerCompanionPlayback.smoothedRate(
          current: companionRate, target: targetCompanionRate, elapsed: elapsed)
      }
      let state = companionBehavior.update(
        at: companionTime,
        cpu: cpuUsage,
        isCharging: isCharging,
        idleSeconds: CGEventSource.secondsSinceLastEventType(
          .combinedSessionState, eventType: CGEventType(rawValue: UInt32.max)!
        ),
        displaySleeping: displaySleeping
      )
      if renderedState != state {
        installCompanionAnimation(state)
        synchronizeActivityClock()
        item.button?.toolTip = String(localized: "Status pup") + " · " + state.title + "\n" +
          String(localized: "Click to spin · Right-click for menu")
      }
      setPlaybackSpeed(Float(companionRate))
    } else if RunnerFrame.shared.runner != nil {
      let fps = RunnerConfig.minFPS + (RunnerConfig.maxFPS - RunnerConfig.minFPS) * smoothedCPU / 100
      setPlaybackSpeed(shouldPause ? 0 : Float(fps / RunnerConfig.minFPS))
    }
  }

  private func currentCompanionSprite() -> RunnerCompanionArt.Sprite? {
    guard let state = renderedState else { return nil }
    let elapsed = max(0, companionTime - renderedSince)
    if !transitionSprites.isEmpty, elapsed < RunnerCompanionState.transitionDuration {
      let frame = min(transitionSprites.count - 1,
                      Int(elapsed / RunnerCompanionState.transitionDuration * Double(transitionSprites.count)))
      return transitionSprites[frame]
    }
    return RunnerCompanionArt.sprite(state: state,
      elapsed: elapsed - (transitionSprites.isEmpty ? 0 : RunnerCompanionState.transitionDuration))
  }

  private func installCompanionAnimation(_ state: RunnerCompanionState) {
    guard let layer = RunnerLayer.shared.layer else { return }
    let source = companionPaused ? nil : currentCompanionSprite()
    let frames = RunnerCompanionArt.frames(for: state, scale: currentScale)
    guard let first = frames.first else { return }
    let sprites = source.map { RunnerCompanionArt.transitionSprites(from: $0, to: state) } ?? []
    let transition = RunnerCompanionArt.frames(for: sprites, scale: currentScale)
    let delay = transition.isEmpty ? 0 : RunnerCompanionState.transitionDuration
    companionAnimationGeneration &+= 1

    CATransaction.begin()
    CATransaction.setDisableActions(true)
    layer.removeAllAnimations()
    layer.speed = 1
    layer.timeOffset = 0
    layer.beginTime = 0
    layer.contentsScale = currentScale
    layer.magnificationFilter = .nearest
    layer.minificationFilter = .nearest
    layer.contents = first
    layer.isHidden = false
    let bounds = item.button?.bounds ?? .zero
    layer.frame = bounds.insetBy(dx: (bounds.width - RunnerCompanionArt.size.width) / 2, dy: 0)
    item.button?.image = nil
    let start = layer.convertTime(CACurrentMediaTime(), from: nil)

    func animation(_ images: [CGImage], duration: TimeInterval) -> CAKeyframeAnimation {
      let animation = CAKeyframeAnimation(keyPath: "contents")
      animation.values = images
      animation.keyTimes = images.indices.map { NSNumber(value: Double($0) / Double(images.count)) }
      animation.calculationMode = .discrete
      animation.duration = duration
      return animation
    }
    // A sleeping pose has one frame and needs no repeating animation.
    if frames.count > 1 {
      let action = animation(frames, duration: state.cycleDuration)
      action.beginTime = start + delay
      action.repeatCount = state.loops ? .infinity : 1
      action.fillMode = .forwards
      action.isRemovedOnCompletion = false
      if state == .happy {
        action.delegate = self
        action.setValue(NSNumber(value: companionAnimationGeneration), forKey: "companionGeneration")
      }
      layer.add(action, forKey: "runner")
    }
    if !transition.isEmpty {
      let entry = animation(transition, duration: delay)
      entry.beginTime = start
      layer.add(entry, forKey: "companionTransition")
    }
    CATransaction.commit()
    transitionSprites = sprites
    renderedSince = companionTime
    renderedState = state
  }

  nonisolated func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
    guard flag, let generation = (anim.value(forKey: "companionGeneration") as? NSNumber)?.uint64Value else { return }
    Task { @MainActor [weak self] in
      guard let self, AppState.shared.runnerCompanion, !self.companionPaused,
            self.renderedState == .happy, self.companionAnimationGeneration == generation else { return }
      // Finish on the animation's clock instead of waiting for the activity timer.
      self.companionTime = max(self.companionTime,
        (self.renderedSince + RunnerCompanionState.happy.cycleDuration).nextUp)
      self.lastCompanionTick = ProcessInfo.processInfo.systemUptime
      self.refreshBehavior()
    }
  }

  private func synchronizeActivityClock() {
    guard AppState.shared.runnerCompanion, !companionPaused, companionNeedsActivityClock else {
      activityClock?.cancel()
      activityClock = nil
      activityInterval = nil
      return
    }
    let interval: TimeInterval = 1
    guard activityClock == nil || activityInterval != interval else { return }
    activityClock?.cancel()
    activityInterval = interval
    // Only short actions need this clock. Resting consumes the existing system
    // samples instead, while Core Animation continues drawing every sprite frame.
    activityClock = Timer.publish(every: interval, tolerance: interval * 0.2, on: .main, in: .common)
      .autoconnect()
      .sink { [weak self] _ in self?.refreshBehavior() }
  }

  // Preserve the current frame/time when the CPU sample changes or playback pauses.
  private func setPlaybackSpeed(_ speed: Float) {
    guard let layer = RunnerLayer.shared.layer, layer.animationKeys()?.isEmpty == false else { return }
    // CPU smoothing changes by tiny amounts even when the visible pace is the
    // same. Avoid committing a new Core Animation clock for imperceptible drift.
    let nextSpeed = speed == 0 ? 0 : (speed * 20).rounded() / 20
    guard layer.speed != nextSpeed else { return }
    let now = CACurrentMediaTime()
    let localTime = layer.convertTime(now, from: nil)
    let parentTime = layer.superlayer?.convertTime(now, from: nil) ?? now
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    layer.speed = nextSpeed
    layer.timeOffset = localTime
    layer.beginTime = parentTime
    CATransaction.commit()
  }

  @objc private func companionClicked() {
    if let event = NSApp.currentEvent, event.type == .rightMouseUp {
      guard let button = item.button else { return }
      NSMenu.popUpContextMenu(AppMenu.shared.getMenus(), with: event, for: button)
      return
    }
    greet()
  }

  func greet() {
    guard AppState.shared.runnerCompanion else { return }
    companionBehavior.requestGreeting()
    refreshBehavior()
  }

  private func reactToInteraction() {
    guard AppState.shared.runnerCompanion, !companionPaused, !lowPowerEnabled,
          renderedState != .happy, renderedState != .sleeping,
          item.button?.window?.isVisible == true,
          reactionGate.accept(at: ProcessInfo.processInfo.systemUptime) else { return }
    greet()
  }

  private func observe() {
    cancellables.removeAll()
    InteractionFeedback.events
      .sink { [weak self] _ in self?.reactToInteraction() }
      .store(in: &cancellables)
    SystemMetrics.shared.$bundle
      .sink { [weak self] bundle in
        guard let self else { return }
        let sequence = SystemMetrics.shared.sampleSequence
        if self.lastCPUSample != sequence {
          self.lastCPUSample = sequence
          let cpu = bundle?.cpuInfo?.percentage.value ?? 0
          self.cpuUsage = cpu.isFinite ? min(100, max(0, cpu)) : 0
          self.smoothedCPU = self.smoothedCPU * 0.6 + self.cpuUsage * 0.4
        }
        self.isCharging = bundle?.batteryInfo?.isCharging ?? false
        // Reuse the sampling clock for resting/sleeping; do not wake an extra
        // timer just to read the same CPU/battery values between samples.
        if !AppState.shared.runnerCompanion || !self.companionNeedsActivityClock { self.refreshBehavior() }
      }
      .store(in: &cancellables)

    NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in self?.screenChanged() }
      .store(in: &cancellables)
    observeStatusWindow()
    let workspace = NSWorkspace.shared.notificationCenter
    workspace.publisher(for: NSWorkspace.screensDidSleepNotification)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.displaySleeping = true
        self?.synchronizeActivityClock()
        self?.refreshBehavior()
      }
      .store(in: &cancellables)
    workspace.publisher(for: NSWorkspace.screensDidWakeNotification)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.displaySleeping = false
        self?.synchronizeActivityClock()
        self?.refreshBehavior()
      }
      .store(in: &cancellables)
    NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)
      .merge(with: workspace.publisher(for: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification))
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        guard let self else { return }
        self.lowPowerEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        self.reduceMotionEnabled = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        self.synchronizeActivityClock()
        self.refreshBehavior()
      }
      .store(in: &cancellables)
  }

  private func screenChanged() {
    observeStatusWindow()
    guard renderedScale != currentScale else { return }
    reload()
  }

  private func observeStatusWindow() {
    let window = item.button?.window
    guard observedWindow !== window || window == nil else { return }
    windowObservation?.cancel()
    windowObservation = nil
    observedWindow = window
    guard let window else { return }
    windowObservation = NotificationCenter.default.publisher(for: NSWindow.didChangeScreenNotification, object: window)
      .merge(with: NotificationCenter.default.publisher(for: NSWindow.didChangeBackingPropertiesNotification, object: window))
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in self?.screenChanged() }
  }
}
