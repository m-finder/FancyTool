import AppKit
import Carbon.HIToolbox
import Combine
import KeyboardShortcuts

private let shotterHotKeySignature: OSType = 0x46545348 // FTSH

private func shotterHotKeyEventHandler(
  _ call: EventHandlerCallRef?,
  _ event: EventRef?,
  _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
  guard let event,
        GetEventClass(event) == OSType(kEventClassKeyboard) else {
    return OSStatus(eventNotHandledErr)
  }
  let kind = GetEventKind(event)
  guard kind == UInt32(kEventHotKeyPressed) || kind == UInt32(kEventHotKeyReleased) else {
    return OSStatus(eventNotHandledErr)
  }

  var hotKeyID = EventHotKeyID()
  let status = GetEventParameter(
    event,
    UInt32(kEventParamDirectObject),
    UInt32(typeEventHotKeyID),
    nil,
    MemoryLayout<EventHotKeyID>.size,
    nil,
    &hotKeyID
  )
  guard status == noErr else { return status }
  guard hotKeyID.signature == shotterHotKeySignature else {
    return OSStatus(eventNotHandledErr)
  }

  let identifier = hotKeyID.id
  let isPressed = kind == UInt32(kEventHotKeyPressed)
  DispatchQueue.main.async {
    ShotterShortcut.shared.handleKeyEvent(identifier: identifier, isPressed: isPressed)
  }
  return noErr
}

@MainActor
final class ShotterShortcut: ObservableObject {

  static let shared = ShotterShortcut()

  @Published private(set) var registrationError: OSStatus?

  private var hotKey: EventHotKeyRef?
  private var eventHandler: EventHandlerRef?
  private var observers: Set<AnyCancellable> = []
  private var action: (() -> Void)?
  private var isMounted = false
  private var isRecording = false
  private var nextIdentifier: UInt32 = 0
  private var activeIdentifier: UInt32?
  private var pressedIdentifier: UInt32?

  private init() {
    // KeyboardShortcuts 2.3.0 has no public recording-state/registration
    // observer. Reuse its notifications so the existing recorder and saved
    // shortcut stay intact while only Shotter uses exclusive registration.
    NotificationCenter.default.publisher(
      for: Notification.Name("KeyboardShortcuts_shortcutByNameDidChange")
    )
    .receive(on: RunLoop.main)
    .sink { [weak self] notification in
      guard let name = notification.userInfo?["name"] as? KeyboardShortcuts.Name,
            name == .shotter else { return }
      self?.updateRegistration()
    }
    .store(in: &observers)

    NotificationCenter.default.publisher(
      for: Notification.Name("KeyboardShortcuts_recorderActiveStatusDidChange")
    )
    .receive(on: RunLoop.main)
    .sink { [weak self] notification in
      guard let self,
            let isActive = notification.userInfo?["isActive"] as? Bool,
            self.isRecording != isActive else { return }
      self.isRecording = isActive
      self.updateRegistration()
    }
    .store(in: &observers)
  }

  func mount(action: @escaping () -> Void) {
    self.action = action
    guard !isMounted else { return }
    isMounted = true
    updateRegistration()
  }

  func unmount() {
    isMounted = false
    action = nil
    updateRegistration()
    if let eventHandler {
      RemoveEventHandler(eventHandler)
      self.eventHandler = nil
    }
  }

  private func updateRegistration() {
    activeIdentifier = nil
    pressedIdentifier = nil
    if let hotKey {
      UnregisterEventHotKey(hotKey)
      self.hotKey = nil
    }

    // Saving a shortcut also registers it non-exclusively inside the library,
    // even without a listener. Remove that registration before claiming it.
    KeyboardShortcuts.disable(.shotter)
    registrationError = nil
    guard isMounted, !isRecording,
          let shortcut = KeyboardShortcuts.getShortcut(for: .shotter) else { return }

    if eventHandler == nil {
      var eventTypes = [
        EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
        EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
      ]
      let status = InstallEventHandler(
        GetEventDispatcherTarget(),
        shotterHotKeyEventHandler,
        eventTypes.count,
        &eventTypes,
        nil,
        &eventHandler
      )
      guard status == noErr else {
        registrationError = status
        return
      }
    }

    nextIdentifier &+= 1
    let identifier = nextIdentifier
    let status = RegisterEventHotKey(
      UInt32(shortcut.carbonKeyCode),
      UInt32(shortcut.carbonModifiers),
      EventHotKeyID(signature: shotterHotKeySignature, id: identifier),
      GetEventDispatcherTarget(),
      UInt32(kEventHotKeyExclusive),
      &hotKey
    )
    guard status == noErr else {
      registrationError = status
      return
    }
    activeIdentifier = identifier
  }

  fileprivate func handleKeyEvent(identifier: UInt32, isPressed: Bool) {
    // Unmounting, recording, or changing the binding invalidates queued key-up
    // events. A new registration always gets a new identifier.
    guard isMounted, !isRecording, activeIdentifier == identifier else { return }
    if isPressed {
      pressedIdentifier = identifier
      return
    }
    // The recorder can restore registration before its recording key is
    // released. Require a fresh press so finishing a recording cannot capture.
    guard pressedIdentifier == identifier else { return }
    pressedIdentifier = nil
    action?()
  }
}
