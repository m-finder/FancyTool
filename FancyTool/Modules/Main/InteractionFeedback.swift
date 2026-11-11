import Combine
import Foundation

/// In-process user actions only. No notification delivery or background clock.
@MainActor
enum InteractionFeedback {
  enum Event { case screenshotCopied, signatureChanged }
  static let events = PassthroughSubject<Event, Never>()
}

struct CompanionReactionGate {
  static let cooldown: TimeInterval = 20
  private var lastReaction: TimeInterval?

  mutating func accept(at time: TimeInterval) -> Bool {
    guard time.isFinite, time >= 0 else { return false }
    if let lastReaction, time - lastReaction < Self.cooldown { return false }
    lastReaction = time
    return true
  }
}
