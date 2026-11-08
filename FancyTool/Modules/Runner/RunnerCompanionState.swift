import Foundation

enum RunnerCompanionPlayback {
  static func rate(cpu: Double, lowPower: Bool) -> Double {
    let usage = cpu.isFinite ? min(100, max(0, cpu)) : 0
    return (0.75 + usage / 100 * 0.75) * (lowPower ? 0.5 : 1)
  }

  static func smoothedRate(current: Double, target: Double, elapsed: TimeInterval) -> Double {
    guard elapsed.isFinite, elapsed > 0 else { return current }
    // Ease into load changes over 1.5 seconds without resetting the animation.
    return current + (target - current) * (1 - exp(-elapsed / 1.5))
  }
}

enum RunnerCompanionState: CaseIterable {
  case idle, walking, stretching, busy, charging, sleeping, happy

  static func resolve(
    cpu: Double,
    isCharging: Bool,
    idleSeconds: TimeInterval,
    displaySleeping: Bool,
    previous: Self
  ) -> Self {
    if displaySleeping || idleSeconds >= 60 { return .sleeping }
    // Separate enter/leave thresholds avoid flickering near the busy boundary.
    if cpu >= 55 || (previous == .busy && cpu >= 35) { return .busy }
    if isCharging { return .charging }
    return .idle
  }

  static let transitionDuration: TimeInterval = 0.72

  var frameCount: Int {
    RunnerCompanionArt.sequence(for: self).count
  }

  var loops: Bool {
    self == .idle || self == .walking || self == .busy || self == .sleeping
  }

  var cycleDuration: TimeInterval { Double(frameCount) * frameDuration }

  var actionDuration: TimeInterval? {
    switch self {
    case .walking: cycleDuration * 2 + Self.transitionDuration
    case .stretching, .charging: cycleDuration + Self.transitionDuration
    case .happy: cycleDuration
    default: nil
    }
  }

  var frameDuration: TimeInterval {
    switch self {
    case .idle: 0.18
    case .walking: 0.14
    case .stretching: 0.14
    case .busy: 0.1
    case .charging: 0.16
    case .sleeping: 0.2
    case .happy: 0.1
    }
  }

  var title: String {
    switch self {
    case .idle: String(localized: "Relaxing")
    case .walking: String(localized: "Taking a stroll")
    case .stretching: String(localized: "Looking around")
    case .busy: String(localized: "Working hard")
    case .charging: String(localized: "Recharging")
    case .sleeping: String(localized: "Taking a nap")
    case .happy: String(localized: "Spinning!")
    }
  }
}

/// Uses playback time, so pauses and low-power playback also pause/slow actions.
/// System signals choose a mood; completed actions and rest periods choose when
/// the companion can move into that mood.
struct RunnerCompanionBehavior {
  private(set) var state: RunnerCompanionState = .idle
  private var stateSince: TimeInterval = 0
  private var systemState: RunnerCompanionState = .idle
  private var pendingSystemState: RunnerCompanionState = .idle
  private var pendingSince: TimeInterval = 0
  private var greetingRequested = false
  private var nextRelaxedAction: RunnerCompanionState = .stretching
  private var restDuration: TimeInterval = 18
  private var nextSnackAt: TimeInterval = 0

  mutating func requestGreeting() {
    // Repeated clicks do not restart the greeting halfway through.
    if state != .happy { greetingRequested = true }
  }

  mutating func update(
    at time: TimeInterval, cpu: Double, isCharging: Bool,
    idleSeconds: TimeInterval, displaySleeping: Bool
  ) -> RunnerCompanionState {
    guard time.isFinite, time >= 0 else { return state }
    let requestedSystemState = RunnerCompanionState.resolve(
      cpu: cpu, isCharging: isCharging, idleSeconds: idleSeconds,
      displaySleeping: displaySleeping, previous: systemState
    )
    if requestedSystemState != pendingSystemState {
      pendingSystemState = requestedSystemState
      pendingSince = time
    }
    let confirmation: TimeInterval = switch requestedSystemState {
    case .busy: 6
    case .charging: 3
    case .sleeping: 0
    default: systemState == .busy ? 8 : 2
    }
    if time - pendingSince >= confirmation { systemState = requestedSystemState }

    if displaySleeping {
      greetingRequested = false
      enter(.sleeping, at: time)
      return state
    }
    if greetingRequested {
      greetingRequested = false
      enter(.happy, at: time)
      return state
    }
    let age = time - stateSince
    guard age >= RunnerCompanionState.transitionDuration else { return state }

    if state == .sleeping {
      if requestedSystemState != .sleeping {
        // Wake, look around once, then rest before responding to system activity.
        systemState = .idle
        pendingSince = time
        enter(.stretching, at: time)
      }
    } else if let duration = state.actionDuration {
      if age >= duration { enter(.idle, at: time) }
    } else if systemState == .sleeping {
      enter(.sleeping, at: time)
    } else if state == .busy {
      if systemState != .busy && age >= 8 { enter(.idle, at: time) }
    } else if age >= 3 && systemState == .busy {
      enter(.busy, at: time)
    } else if age >= 8 && systemState == .charging && time >= nextSnackAt {
      nextSnackAt = time + 90
      enter(.charging, at: time)
    } else if age >= restDuration {
      let action = nextRelaxedAction
      nextRelaxedAction = action == .stretching ? .walking : .stretching
      restDuration = action == .stretching ? 24 : 18
      enter(action, at: time)
    }
    return state
  }

  private mutating func enter(_ next: RunnerCompanionState, at time: TimeInterval) {
    guard next != state else { return }
    state = next
    stateSince = time
  }
}
