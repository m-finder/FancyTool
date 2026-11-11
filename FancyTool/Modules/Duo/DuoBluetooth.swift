import AppKit
import IOBluetooth
import CoreBluetooth
import Darwin

@MainActor
final class DuoBluetooth: NSObject, ObservableObject, CBCentralManagerDelegate {
  static let shared = DuoBluetooth()
  struct Device: Identifiable, Sendable {
    let id: String
    let name: String
    let connected: Bool
  }
  @Published private(set) var powered: Bool?
  @Published private(set) var devices: [Device] = []
  @Published private(set) var busyDeviceID: String?
  @Published private(set) var powerBusy = false
  @Published private(set) var error: String?
  @Published private(set) var authorization = CBManager.authorization
  private var permissionManager: CBCentralManager?
  private var pendingPower: Bool?

  // Optional IOBluetooth exports: resolve at runtime so an unavailable symbol
  // disables the control instead of preventing the application from launching.
  private typealias PowerGetter = @convention(c) () -> Int32
  private typealias PowerSetter = @convention(c) @Sendable (Int32) -> Void
  private static let library = dlopen("/System/Library/Frameworks/IOBluetooth.framework/IOBluetooth", RTLD_LAZY)
  private static let powerGetter: PowerGetter? = {
    guard let library, let symbol = dlsym(library, "IOBluetoothPreferenceGetControllerPowerState") else { return nil }
    return unsafeBitCast(symbol, to: PowerGetter.self)
  }()
  private static let powerSetter: PowerSetter? = {
    guard let library, let symbol = dlsym(library, "IOBluetoothPreferenceSetControllerPowerState") else { return nil }
    return unsafeBitCast(symbol, to: PowerSetter.self)
  }()

  var busy: Bool { busyDeviceID != nil || powerBusy || pendingPower != nil }
  var canSetPower: Bool { Self.powerGetter != nil && Self.powerSetter != nil }
  var emptyMessage: String {
    switch authorization {
    case .notDetermined: return String(localized: "Allow Bluetooth access to show paired devices.")
    case .denied, .restricted: return String(localized: "Allow Bluetooth access in System Settings to manage paired devices.")
    default: return String(localized: "No paired Bluetooth devices")
    }
  }

  var status: String {
    if powered == false { return String(localized: "Off") }
    let count = devices.filter(\.connected).count
    return count > 0 ? String(localized: "\(count) connected") : String(localized: "Devices")
  }
  func refreshIfAuthorized() {
    if CBManager.authorization == .allowedAlways { refresh() }
    else { refreshPower() }
  }
  func requestAccess() {
    authorization = CBManager.authorization
    if authorization == .notDetermined {
      guard permissionManager == nil else { return }
      // Request Bluetooth permission only when the user opens device controls.
      // No scanning, power alert or permanent CoreBluetooth manager is needed.
      permissionManager = CBCentralManager(delegate: self, queue: .main,
        options: [CBCentralManagerOptionShowPowerAlertKey: false])
    } else {
      error = nil
      refresh()
    }
  }
  nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
    MainActor.assumeIsolated {
      authorization = CBManager.authorization
      guard authorization != .notDetermined else { return }
      error = nil
      refresh()
      permissionManager?.delegate = nil
      permissionManager = nil
      let requested = pendingPower
      pendingPower = nil
      if authorization == .allowedAlways, let requested { setPowered(requested) }
    }
  }
  func refresh() {
    authorization = CBManager.authorization
    refreshPower()
    guard authorization == .allowedAlways else {
      devices = []
      if authorization == .notDetermined { return }
      error = String(localized: "Allow Bluetooth access in System Settings to manage paired devices.")
      return
    }
    devices = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []).compactMap {
      guard let address = $0.addressString else { return nil }
      return Device(id: address, name: $0.name ?? address, connected: $0.isConnected())
    }.sorted {
      if $0.connected != $1.connected { return $0.connected }
      return $0.name.localizedStandardCompare($1.name) == .orderedAscending
    }
  }
  private func refreshPower() {
    if let getter = Self.powerGetter {
      let state = getter()
      powered = (0...1).contains(state) ? state == 1 : nil
    } else {
      powered = IOBluetoothHostController.default().map { $0.powerState.rawValue == 1 }
    }
  }
  func setPowered(_ enabled: Bool) {
    guard !busy, let setter = Self.powerSetter, Self.powerGetter != nil else { return }
    authorization = CBManager.authorization
    if authorization == .notDetermined {
      pendingPower = enabled
      requestAccess()
      return
    }
    guard authorization == .allowedAlways else { refresh(); return }
    powerBusy = true
    error = nil
    Task {
      await Task.detached(priority: .userInitiated) { setter(enabled ? 1 : 0) }.value
      // Confirm the requested state only after a click; no idle timer or scan.
      for _ in 0..<12 {
        refreshPower()
        if powered == enabled { break }
        try? await Task.sleep(for: .milliseconds(250))
      }
      refresh()
      if powered != enabled { error = String(localized: "Unable to change Bluetooth power. Please try again.") }
      powerBusy = false
    }
  }
  func toggle(_ device: Device) {
    guard !busy, powered == true else { return }
    busyDeviceID = device.id
    Task {
      let result = await Task.detached {
        guard let current = IOBluetoothDevice(addressString: device.id) else { return false }
        return (current.isConnected() ? current.closeConnection() : current.openConnection()) == kIOReturnSuccess
      }.value
      busyDeviceID = nil
      error = result ? nil : String(localized: "Unable to connect this Bluetooth device. Open Bluetooth Settings to continue.")
      refresh()
    }
  }
}
