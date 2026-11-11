import AppKit
import CoreLocation
import CoreWLAN

@MainActor
final class DuoWiFi: NSObject, ObservableObject, CLLocationManagerDelegate {
  struct Network: Identifiable, Sendable {
    let id: String
    let name: String
    let known: Bool
    let secured: Bool
    let enterprise: Bool
    let connected: Bool
  }

  @Published private(set) var networks: [Network] = []
  @Published private(set) var currentName: String?
  @Published private(set) var scanning = false
  @Published private(set) var busyNetworkID: String?
  @Published private(set) var error: String?
  @Published private(set) var authorization: CLAuthorizationStatus
  private let locationManager = CLLocationManager()
  private var scanGeneration = 0
  private var connectionGeneration = 0
  private var awaitingAuthorization = false

  var authorized: Bool { authorization == .authorizedAlways }
  var busy: Bool { scanning || busyNetworkID != nil }
  var emptyMessage: String {
    switch authorization {
    case .notDetermined: return String(localized: "Allow Location access to show nearby Wi-Fi networks.")
    case .denied, .restricted: return String(localized: "Allow Location access in System Settings to show nearby Wi-Fi networks.")
    default: return scanning ? String(localized: "Scanning for networks…") : String(localized: "No Wi-Fi networks found")
    }
  }

  override init() {
    authorization = locationManager.authorizationStatus
    super.init()
    locationManager.delegate = self
  }

  func requestAccess() {
    authorization = locationManager.authorizationStatus
    if authorization == .notDetermined {
      // Opening the network list is the only place that requests Location access.
      awaitingAuthorization = true
      // A nonactivating menu-bar panel may not count as a foreground app for TCC.
      NSApp.activate(ignoringOtherApps: true)
      locationManager.requestWhenInUseAuthorization()
    } else if authorized {
      refresh()
    } else {
      clear()
    }
  }

  nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    Task { @MainActor [weak self] in
      guard let self else { return }
      let previous = self.authorization
      self.authorization = self.locationManager.authorizationStatus
      if self.authorized && self.awaitingAuthorization && previous != self.authorization { self.refresh() }
      if self.authorization != .notDetermined { self.awaitingAuthorization = false }
      if !self.authorized { self.clear() }
    }
  }

  func refresh() {
    guard authorized else { requestAccess(); return }
    guard !scanning else { return }
    scanGeneration += 1
    connectionGeneration += 1
    let generation = scanGeneration
    let connectionRequest = connectionGeneration
    scanning = true
    error = nil
    Task {
      let result = await Task.detached(priority: .userInitiated) { Self.readNetworks() }.value
      guard generation == scanGeneration else { return }
      scanning = false
      networks = result.networks
      if connectionRequest == connectionGeneration { currentName = result.currentName }
      if let scanError = result.error { error = scanError }
    }
  }

  func refreshCurrentConnectionIfAuthorized() {
    guard authorized else { return }
    connectionGeneration += 1
    let generation = connectionGeneration
    Task {
      let name = await Task.detached(priority: .utility) {
        guard let interface = CWWiFiClient.shared().interface(), interface.powerOn() else { return nil as String? }
        return interface.ssid()
      }.value
      guard generation == connectionGeneration, authorized else { return }
      currentName = name
    }
  }

  func clear() {
    scanGeneration += 1
    connectionGeneration += 1
    scanning = false
    networks = []
    currentName = nil
    error = nil
  }

  func connect(_ network: Network, password: String? = nil) async -> Bool {
    guard authorized, busyNetworkID == nil else { return false }
    busyNetworkID = network.id
    error = nil
    let succeeded = await Task.detached(priority: .userInitiated) {
      guard let interface = CWWiFiClient.shared().interface() else { return false }
      if network.connected { interface.disassociate(); return true }
      guard let target = try? interface.scanForNetworks(withName: network.name)
        .first(where: { $0.ssid == network.name }) else { return false }
      do { try interface.associate(to: target, password: password); return true }
      catch { return false }
    }.value
    busyNetworkID = nil
    refresh()
    error = succeeded ? nil : String(localized: "Unable to connect to this Wi-Fi network.")
    return succeeded
  }

  private struct ScanResult: Sendable {
    let networks: [Network]
    let currentName: String?
    let error: String?
  }

  private nonisolated static func readNetworks() -> ScanResult {
    guard let interface = CWWiFiClient.shared().interface(), interface.powerOn() else {
      return ScanResult(networks: [], currentName: nil, error: nil)
    }
    let current = interface.ssid()
    do {
      let profiles = Set((interface.configuration()?.networkProfiles.array as? [CWNetworkProfile] ?? []).compactMap(\.ssid))
      let scanned = try interface.scanForNetworks(withName: nil)
      var strongest: [String: CWNetwork] = [:]
      for network in scanned {
        guard let name = network.ssid, !name.isEmpty else { continue }
        if let previous = strongest[name], previous.rssiValue >= network.rssiValue { continue }
        strongest[name] = network
      }
      let networks = strongest.map { name, network in
        let open = network.supportsSecurity(.none)
        let enterprise = network.supportsSecurity(.enterprise) || network.supportsSecurity(.wpaEnterprise)
          || network.supportsSecurity(.wpa2Enterprise) || network.supportsSecurity(.wpa3Enterprise)
        return Network(id: name, name: name, known: profiles.contains(name), secured: !open,
                       enterprise: enterprise, connected: name == current)
      }.sorted {
        if $0.connected != $1.connected { return $0.connected }
        if $0.known != $1.known { return $0.known }
        return $0.name.localizedStandardCompare($1.name) == .orderedAscending
      }
      return ScanResult(networks: networks, currentName: current, error: nil)
    } catch {
      return ScanResult(networks: [], currentName: current,
                        error: String(localized: "Unable to scan for Wi-Fi networks."))
    }
  }
}
