import AppKit
import Combine
import CoreAudio
import CoreWLAN
import IOKit.ps
import Network

struct DuoBattery: Sendable, Equatable {
  var percentage: Int
  var charging: Bool
  var pluggedIn: Bool
  var lowPowerMode: Bool
  var lowBattery: Bool

  var symbol: String {
    if charging { return "battery.100percent.bolt" }
    switch percentage {
    case ...10: return "battery.0percent"
    case ...35: return "battery.25percent"
    case ...60: return "battery.50percent"
    case ...85: return "battery.75percent"
    default: return "battery.100percent"
    }
  }
}

struct DuoAudioState: Sendable, Equatable {
  var device: AudioObjectID = kAudioObjectUnknown
  var volume: Double?
  var muted = false
  var canSetVolume = false
  var canMute = false

  var symbol: String {
    if muted || volume == 0 { return "speaker.slash.fill" }
    if let volume, volume < 0.33 { return "speaker.wave.1.fill" }
    if let volume, volume < 0.67 { return "speaker.wave.2.fill" }
    return "speaker.wave.3.fill"
  }
}

struct DuoAudioOutput: Identifiable, Sendable, Equatable {
  let id: AudioObjectID
  let name: String
}

/// Reads and writes only the current output device's public HAL controls.
private enum DuoAudio {
  static func address(_ selector: AudioObjectPropertySelector, element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain,
                      scope: AudioObjectPropertyScope = kAudioDevicePropertyScopeOutput) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
  }

  static func read<T: BitwiseCopyable>(_ object: AudioObjectID, _ address: AudioObjectPropertyAddress, into value: inout T) -> Bool {
    var property = address
    var size = UInt32(MemoryLayout<T>.size)
    return AudioObjectGetPropertyData(object, &property, 0, nil, &size, &value) == noErr
  }

  static func settable(_ object: AudioObjectID, _ address: AudioObjectPropertyAddress) -> Bool {
    var property = address
    var value: DarwinBoolean = false
    return AudioObjectHasProperty(object, &property)
      && AudioObjectIsPropertySettable(object, &property, &value) == noErr && value.boolValue
  }

  static func channels(_ device: AudioObjectID, selector: AudioObjectPropertySelector) -> [AudioObjectPropertyElement] {
    if settable(device, address(selector)) { return [kAudioObjectPropertyElementMain] }
    // Standard stereo devices expose per-channel controls when no master exists.
    return [AudioObjectPropertyElement(1), AudioObjectPropertyElement(2)].filter { settable(device, address(selector, element: $0)) }
  }

  static func snapshot() -> DuoAudioState {
    var state = DuoAudioState()
    guard read(AudioObjectID(kAudioObjectSystemObject),
               address(kAudioHardwarePropertyDefaultOutputDevice, scope: kAudioObjectPropertyScopeGlobal), into: &state.device),
          state.device != kAudioObjectUnknown else { return state }
    var volume: Float32 = 0
    if read(state.device, address(kAudioDevicePropertyVolumeScalar), into: &volume) {
      state.volume = Double(volume)
    } else {
      let values = [AudioObjectPropertyElement(1), AudioObjectPropertyElement(2)].compactMap { channel -> Double? in
        var value: Float32 = 0
        return read(state.device, address(kAudioDevicePropertyVolumeScalar, element: channel), into: &value) ? Double(value) : nil
      }
      if !values.isEmpty { state.volume = values.reduce(0, +) / Double(values.count) }
    }
    state.canSetVolume = !channels(state.device, selector: kAudioDevicePropertyVolumeScalar).isEmpty
    let muteChannels = channels(state.device, selector: kAudioDevicePropertyMute)
    state.canMute = !muteChannels.isEmpty
    var muted: UInt32 = 0
    if read(state.device, address(kAudioDevicePropertyMute), into: &muted) {
      state.muted = muted != 0
    } else if let channel = muteChannels.first {
      _ = read(state.device, address(kAudioDevicePropertyMute, element: channel), into: &muted)
      state.muted = muted != 0
    }
    if let value = state.volume, !value.isFinite || !(0...1).contains(value) { state.volume = nil }
    return state
  }

  static func outputs() -> [DuoAudioOutput] {
    var property = address(kAudioHardwarePropertyDevices, scope: kAudioObjectPropertyScopeGlobal)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &property, 0, nil, &size) == noErr,
          size > 0 else { return [] }
    var devices = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
    let result = devices.withUnsafeMutableBytes {
      AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &property, 0, nil, &size, $0.baseAddress!)
    }
    guard result == noErr else { return [] }
    return devices.compactMap { device in
      var streams = address(kAudioDevicePropertyStreams)
      var streamSize: UInt32 = 0
      guard AudioObjectGetPropertyDataSize(device, &streams, 0, nil, &streamSize) == noErr, streamSize > 0 else { return nil }
      var nameProperty = address(kAudioObjectPropertyName, scope: kAudioObjectPropertyScopeGlobal)
      var name: Unmanaged<CFString>?
      var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
      guard AudioObjectGetPropertyData(device, &nameProperty, 0, nil, &nameSize, &name) == noErr,
            let name else { return nil }
      return DuoAudioOutput(id: device, name: name.takeRetainedValue() as String)
    }
  }

  static func selectOutput(_ device: AudioObjectID) -> Bool {
    var property = address(kAudioHardwarePropertyDefaultOutputDevice, scope: kAudioObjectPropertyScopeGlobal)
    var value = device
    return AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &property, 0, nil,
                                      UInt32(MemoryLayout<AudioObjectID>.size), &value) == noErr
  }

  static func setVolume(_ value: Double, device: AudioObjectID) -> Bool {
    guard value.isFinite else { return false }
    let targets = channels(device, selector: kAudioDevicePropertyVolumeScalar)
    guard !targets.isEmpty else { return false }
    var success = true
    for channel in targets {
      var property = address(kAudioDevicePropertyVolumeScalar, element: channel)
      var scalar = Float32(min(1, max(0, value)))
      if AudioObjectSetPropertyData(device, &property, 0, nil, UInt32(MemoryLayout<Float32>.size), &scalar) != noErr { success = false }
    }
    return success
  }

  static func setMuted(_ muted: Bool, device: AudioObjectID) -> Bool {
    let targets = channels(device, selector: kAudioDevicePropertyMute)
    guard !targets.isEmpty else { return false }
    var success = true
    for channel in targets {
      var property = address(kAudioDevicePropertyMute, element: channel)
      var value: UInt32 = muted ? 1 : 0
      if AudioObjectSetPropertyData(device, &property, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value) != noErr { success = false }
    }
    return success
  }
}

@MainActor
final class DuoMetrics: NSObject, ObservableObject, CWEventDelegate {
  static let shared = DuoMetrics()
  @Published private(set) var battery: DuoBattery?
  @Published private(set) var wifiPowered: Bool?
  @Published private(set) var wifiConnected = false
  @Published private(set) var online = false
  @Published private(set) var ethernet = false
  @Published private(set) var audio = DuoAudioState()
  @Published private(set) var outputDevices: [DuoAudioOutput] = []
  @Published private(set) var error: String?

  @Published private(set) var wifiBusy = false

  private var started = false
  private var wifiMonitor: NWPathMonitor?
  private let wifiClient = CWWiFiClient()
  private var powerSource: CFRunLoopSource?
  private var powerStateObserver: NSObjectProtocol?
  private var observers: [NSObjectProtocol] = []
  private var sleeping = false
  private var audioRefreshPending = false
  private var outputsRefreshPending = false
  private var observedAudioDevice: AudioObjectID = kAudioObjectUnknown
  private struct AudioListener {
    let object: AudioObjectID
    var address: AudioObjectPropertyAddress
    let block: AudioObjectPropertyListenerBlock
  }
  private var audioListeners: [AudioListener] = []

  func start() {
    guard !started else { return }
    started = true
    sleeping = false
    let wifi = NWPathMonitor(requiredInterfaceType: .wifi)
    wifi.pathUpdateHandler = { [weak self, weak wifi] path in
      let connected = path.status == .satisfied
      // This callback only updates UI state. Deliver it on main directly,
      // without a separate utility queue and Swift concurrency task.
      MainActor.assumeIsolated {
        guard let self, let wifi, self.started, self.wifiMonitor === wifi else { return }
        if self.wifiConnected != connected { self.wifiConnected = connected }
        self.refreshWiFi()
      }
    }
    wifiMonitor = wifi
    wifi.start(queue: .main)
    wifiClient.delegate = self
    try? wifiClient.startMonitoringEvent(with: .powerDidChange)
    powerSource = IOPSNotificationCreateRunLoopSource({ context in
      guard let context else { return }
      MainActor.assumeIsolated {
        Unmanaged<DuoMetrics>.fromOpaque(context).takeUnretainedValue().refreshBattery()
      }
    }, Unmanaged.passUnretained(self).toOpaque())?.takeRetainedValue()
    if let powerSource { CFRunLoopAddSource(CFRunLoopGetMain(), powerSource, .commonModes) }
    powerStateObserver = NotificationCenter.default.addObserver(forName: .NSProcessInfoPowerStateDidChange,
                                                                object: nil, queue: .main) { [weak self] _ in
      MainActor.assumeIsolated { self?.refreshBattery() }
    }
    let workspace = NSWorkspace.shared.notificationCenter
    observers.append(workspace.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
      MainActor.assumeIsolated { self?.sleeping = true }
    })
    observers.append(workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
      MainActor.assumeIsolated { self?.sleeping = false; self?.refresh() }
    })
    for selector in [kAudioHardwarePropertyDefaultOutputDevice, kAudioHardwarePropertyDevices] {
      observeAudio(AudioObjectID(kAudioObjectSystemObject), DuoAudio.address(selector, scope: kAudioObjectPropertyScopeGlobal))
    }
    refreshOutputs()
    refresh()
  }

  func stop() {
    started = false
    wifiMonitor?.cancel(); wifiMonitor = nil
    try? wifiClient.stopMonitoringEvent(with: .powerDidChange)
    wifiClient.delegate = nil
    if let powerSource { CFRunLoopSourceInvalidate(powerSource) }
    powerSource = nil
    if let powerStateObserver { NotificationCenter.default.removeObserver(powerStateObserver) }
    powerStateObserver = nil
    removeAudioListeners()
    observedAudioDevice = kAudioObjectUnknown
    for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    observers.removeAll()
  }

  func refresh() {
    guard !sleeping else { return }
    refreshBattery()
    refreshWiFi()
    refreshAudio()
  }

  private func refreshBattery() {
    guard started, !sleeping else { return }
    let next = readBattery()
    if battery != next { battery = next }
  }

  private func refreshWiFi() {
    guard started, !sleeping else { return }
    let next = wifiClient.interface()?.powerOn()
    if wifiPowered != next { wifiPowered = next }
  }

  nonisolated func powerStateDidChangeForWiFiInterface(withName interfaceName: String) {
    Task { @MainActor [weak self] in self?.refreshWiFi() }
  }

  private func observeAudio(_ object: AudioObjectID, _ address: AudioObjectPropertyAddress) {
    var address = address
    let updatesOutputs = address.mSelector == kAudioHardwarePropertyDevices
    let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
      MainActor.assumeIsolated { self?.scheduleAudioRefresh(outputsChanged: updatesOutputs) }
    }
    if AudioObjectAddPropertyListenerBlock(object, &address, .main, block) == noErr {
      audioListeners.append(AudioListener(object: object, address: address, block: block))
    }
  }

  private func removeAudioListeners(deviceOnly: Bool = false) {
    audioListeners.removeAll { listener in
      guard !deviceOnly || listener.object != AudioObjectID(kAudioObjectSystemObject) else { return false }
      var property = listener.address
      AudioObjectRemovePropertyListenerBlock(listener.object, &property, .main, listener.block)
      return true
    }
  }

  private func scheduleAudioRefresh(outputsChanged: Bool) {
    guard started, !sleeping else { return }
    outputsRefreshPending = outputsRefreshPending || outputsChanged
    guard !audioRefreshPending else { return }
    audioRefreshPending = true
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.audioRefreshPending = false
      guard self.started, !self.sleeping else { return }
      self.refreshAudio()
      if self.outputsRefreshPending { self.refreshOutputs(); self.outputsRefreshPending = false }
    }
  }

  private func refreshAudio() {
    let next = DuoAudio.snapshot()
    if audio != next { audio = next }
    guard started, observedAudioDevice != next.device else { return }
    removeAudioListeners(deviceOnly: true)
    observedAudioDevice = next.device
    refreshOutputs()
    guard next.device != kAudioObjectUnknown else { return }
    for selector in [kAudioDevicePropertyVolumeScalar, kAudioDevicePropertyMute] {
      for channel in [AudioObjectPropertyElement(0), 1, 2] {
        observeAudio(next.device, DuoAudio.address(selector, element: channel))
      }
    }
  }

  func refreshOutputs() {
    let next = DuoAudio.outputs()
    if outputDevices != next { outputDevices = next }
  }

  func selectOutput(_ device: DuoAudioOutput) {
    error = DuoAudio.selectOutput(device.id) ? nil : String(localized: "Unable to select this audio output.")
    refreshAudio()
  }

  func setWiFi(_ enabled: Bool) {
    guard !wifiBusy else { return }
    wifiBusy = true
    Task {
      let success = await Task.detached {
        guard let interface = CWWiFiClient.shared().interface() else { return false }
        do { try interface.setPower(enabled); return true } catch { return false }
      }.value
      wifiBusy = false
      error = success ? nil : String(localized: "Unable to change Wi-Fi. Open Wi-Fi Settings to continue.")
      refresh()
    }
  }

  func setVolume(_ value: Double) {
    let current = DuoAudio.snapshot()
    guard current.canSetVolume else { return }
    if DuoAudio.setVolume(value, device: current.device) {
      error = nil
    } else {
      error = String(localized: "Unable to change this audio device's volume.")
    }
    refreshAudio()
  }

  func toggleMute() {
    let current = DuoAudio.snapshot()
    guard current.canMute else { return }
    error = DuoAudio.setMuted(!current.muted, device: current.device) ? nil : String(localized: "Unable to mute this audio device.")
    refreshAudio()
  }

  private func readBattery() -> DuoBattery? {
    guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
          let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
    for source in sources {
      guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
            description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
            description[kIOPSIsPresentKey] as? Bool != false,
            let current = description[kIOPSCurrentCapacityKey] as? Int,
            let maximum = description[kIOPSMaxCapacityKey] as? Int, maximum > 0 else { continue }
      return DuoBattery(percentage: min(100, max(0, Int((Double(current) / Double(maximum) * 100).rounded()))),
                        charging: description[kIOPSIsChargingKey] as? Bool ?? false,
                        pluggedIn: description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue,
                        lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
                        lowBattery: IOPSGetBatteryWarningLevel() != kIOPSLowBatteryWarningNone)
    }
    return nil
  }
}

@MainActor
enum DuoSettingsDestination: String {
  case wifi = "com.apple.wifi-settings-extension"
  case location = "com.apple.preference.security?Privacy_LocationServices"
  case sound = "com.apple.Sound-Settings.extension"
  case bluetooth = "com.apple.BluetoothSettings"
  case displays = "com.apple.Displays-Settings.extension"
  case battery = "com.apple.Battery-Settings.extension"
  case keyboard = "com.apple.Keyboard-Settings.extension"

  func open() {
    Duo.shared.closePanel()
    guard let url = URL(string: "x-apple.systempreferences:\(rawValue)") else { return }
    if !NSWorkspace.shared.open(url) {
      if let settings = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.systempreferences") {
        NSWorkspace.shared.openApplication(at: settings, configuration: NSWorkspace.OpenConfiguration())
      }
    }
  }
}
