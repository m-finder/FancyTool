import SwiftUI

struct DuoPopoverView: View {
  static let panelSize = NSSize(width: 292, height: 332)
  var maximumPanelHeight: CGFloat = 700
  var onHeightChange: (CGFloat) -> Void = { _ in }
  @ObservedObject private var metrics = DuoMetrics.shared
  @ObservedObject private var input = DuoInputSources.shared
  @ObservedObject private var brightness = DuoBrightness.shared
  @ObservedObject private var displayModes = DuoDisplayModes.shared
  @ObservedObject private var bluetooth = DuoBluetooth.shared
  @StateObject private var wifi = DuoWiFi()
  @State private var showsError = false
  @State private var page: Page = .controls
  @State private var selectedNetwork: DuoWiFi.Network?
  @State private var wifiPassword = ""
  @State private var showsOtherNetworks = false
  @State private var wifiListHeight: CGFloat = 80
  @State private var bluetoothListHeight: CGFloat = 80

  private enum Page { case controls, wifi, wifiPassword, sound, bluetooth, input }

  private var preferredPanelHeight: CGFloat {
    switch page {
    case .wifi: min(maximumPanelHeight, max(180, 110 + wifiListHeight))
    case .bluetooth: min(maximumPanelHeight, max(180, 110 + bluetoothListHeight))
    default: Self.panelSize.height
    }
  }
  private var knownNetworks: [DuoWiFi.Network] { wifi.networks.filter { $0.known || $0.connected } }
  private var otherNetworks: [DuoWiFi.Network] { wifi.networks.filter { !$0.known && !$0.connected } }

  private var display: DuoBrightness.Display? {
    brightness.displays.first { $0.brightness != nil } ?? brightness.displays.first
  }
  private var wifiStatus: String {
    if metrics.wifiBusy { return String(localized: "Updating…") }
    if metrics.wifiPowered == false { return String(localized: "Off") }
    if let currentName = wifi.currentName, !currentName.isEmpty { return currentName }
    return metrics.wifiConnected ? String(localized: "Connected") : String(localized: "Not Connected")
  }
  private var error: String? { wifi.error ?? displayModes.error ?? metrics.error ?? brightness.error ?? bluetooth.error ?? input.error }
  private var batteryColor: Color {
    guard let battery = metrics.battery else { return .secondary }
    if battery.lowPowerMode { return .yellow }
    if battery.lowBattery && !battery.pluggedIn && !battery.charging { return .red }
    return .green
  }

  var body: some View {
    Group {
      switch page {
      case .controls: controls
      case .wifi: wifiSelection
      case .wifiPassword: wifiPasswordEntry
      case .sound: outputSelection
      case .bluetooth: bluetoothSelection
      case .input: inputSelection
      }
    }
    .font(.system(size: 11))
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .task {
      bluetooth.refreshIfAuthorized(); metrics.refreshOutputs(); metrics.refresh(); displayModes.refresh()
      wifi.refreshCurrentConnectionIfAuthorized()
    }
    .task(id: page) {
      if page == .wifi, metrics.wifiPowered == true { wifi.requestAccess() }
    }
    .onChange(of: preferredPanelHeight, initial: true) { onHeightChange(preferredPanelHeight) }
    .onChange(of: metrics.wifiPowered) {
      if metrics.wifiPowered == false { wifi.clear() }
      else if metrics.wifiPowered == true {
        if page == .wifi { wifi.requestAccess() }
        else { wifi.refreshCurrentConnectionIfAuthorized() }
      }
    }
    .onReceive(DistributedNotificationCenter.default().publisher(for: Notification.Name("AppleInterfaceThemeChangedNotification"))) { _ in
      displayModes.refresh()
    }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
      displayModes.refresh()
    }
    .alert("Unable to complete action", isPresented: $showsError) {
      Button("OK", role: .cancel) { }
    } message: { Text(error ?? "") }
  }

  private var controls: some View {
    VStack(spacing: 8) {
      header
      HStack(spacing: 8) { wifiTile; bluetoothTile }.frame(height: 62)
      soundCard
      brightnessCard
      inputRow
    }
  }

  private var header: some View {
    HStack(spacing: 6) {
      Text("Duo").font(.system(size: 13, weight: .bold, design: .rounded))
      Spacer(minLength: 4)
      if error != nil {
        Button { showsError = true } label: { Image(systemName: "exclamationmark.circle") }
          .buttonStyle(.plain).foregroundStyle(.orange).help("Action failed · Details")
          .accessibilityLabel("Action failed · Details")
      }
      HStack(spacing: 4) {
        Image(systemName: metrics.battery?.symbol ?? "battery.100percent").frame(width: 19)
          .foregroundStyle(batteryColor)
        Text(metrics.battery.map { PercentText.whole(Double($0.percentage)) } ?? "—")
          .monospacedDigit().font(.system(size: 9, weight: .medium))
      }.padding(.horizontal, 7).padding(.vertical, 4)
        .background(.primary.opacity(0.045), in: Capsule())
        .help(metrics.battery?.charging == true ? "Charging" : "Battery")
        .contextMenu {
          Button("Open System Battery Panel") { DuoSystemPanel.battery.open() }
          Button("Open Battery Settings") { DuoSettingsDestination.battery.open() }
        }
    }.frame(height: 22)
  }

  private var wifiTile: some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack(spacing: 5) {
        Image(systemName: metrics.wifiPowered == false ? "wifi.slash" : "wifi")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(metrics.wifiPowered == true ? Color.accentColor : .secondary)
          .frame(width: 19, height: 22)
        Text("Wi-Fi").font(.system(size: 10, weight: .semibold))
        Spacer(minLength: 0)
        wifiPowerToggle
      }
      Button { showsOtherNetworks = false; page = .wifi } label: {
        HStack {
          Text(wifiStatus).font(.system(size: 9)).lineLimit(1)
          Spacer(minLength: 0)
          Image(systemName: "chevron.right").font(.system(size: 8, weight: .semibold))
        }.foregroundStyle(.secondary).frame(height: 13).contentShape(Rectangle())
      }.buttonStyle(.plain).help("Choose Wi-Fi Network")
        .accessibilityIdentifier("duo.wifi.networks")
    }.padding(9).frame(maxWidth: .infinity).modifier(DuoSurface())
  }

  private var bluetoothTile: some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack(spacing: 5) {
        DuoBluetoothMark()
          .stroke(bluetooth.powered == true ? Color.accentColor : .secondary,
                  style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
          .frame(width: 7, height: 13).frame(width: 19, height: 22)
        Text("Bluetooth").font(.system(size: 10, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
        Spacer(minLength: 0)
        Toggle("Bluetooth", isOn: Binding(get: { bluetooth.powered == true }, set: bluetooth.setPowered))
          .labelsHidden().toggleStyle(.switch).controlSize(.mini).tint(.accentColor)
          .disabled(!bluetooth.canSetPower || bluetooth.busy)
          .accessibilityIdentifier("duo.bluetooth.power")
      }
      Button { bluetooth.requestAccess(); page = .bluetooth } label: {
        HStack {
          Text(bluetooth.busy ? String(localized: "Updating…") : bluetooth.status)
            .font(.system(size: 9)).lineLimit(1)
          Spacer(minLength: 0)
          Image(systemName: "chevron.right").font(.system(size: 8, weight: .semibold))
        }.foregroundStyle(.secondary).frame(height: 13).contentShape(Rectangle())
      }.buttonStyle(.plain).help("Connect or disconnect paired devices")
        .accessibilityIdentifier("duo.bluetooth.devices")
    }.padding(9).frame(maxWidth: .infinity).modifier(DuoSurface())
  }

  private var wifiPowerToggle: some View {
    Toggle("Wi-Fi", isOn: Binding(get: { metrics.wifiPowered == true }, set: metrics.setWiFi))
      .labelsHidden().toggleStyle(.switch).controlSize(.mini).tint(.accentColor)
      .disabled(metrics.wifiPowered == nil || metrics.wifiBusy || wifi.busy)
      .accessibilityIdentifier("duo.wifi.power")
  }

  private var soundCard: some View {
    VStack(spacing: 5) {
      HStack(spacing: 6) {
        Button { metrics.toggleMute() } label: {
          Image(systemName: metrics.audio.symbol).frame(width: 18, height: 16).contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(!metrics.audio.canMute)
          .help(metrics.audio.muted ? "Unmute" : "Mute")
          .accessibilityLabel(metrics.audio.muted ? "Unmute" : "Mute")
          .accessibilityIdentifier("duo.sound.mute")
        Text("Sound").fontWeight(.medium)
        Spacer(minLength: 3)
        percent(metrics.audio.volume)
      }.frame(height: 16)
      DuoLevelSlider(value: Binding(get: { metrics.audio.volume ?? 0 }, set: metrics.setVolume),
                     tint: .accentColor, enabled: metrics.audio.canSetVolume, label: String(localized: "Output Volume"))
        .frame(height: 13)
      Button { metrics.refreshOutputs(); page = .sound } label: {
        HStack(spacing: 4) {
          Image(systemName: "hifispeaker.fill").frame(width: 13)
          Text(metrics.outputDevices.first { $0.id == metrics.audio.device }?.name ?? String(localized: "Output Device"))
            .lineLimit(1)
          Spacer(minLength: 2)
          Image(systemName: "chevron.right").font(.system(size: 8, weight: .semibold))
        }.font(.system(size: 9)).foregroundStyle(.secondary).frame(height: 14).contentShape(Rectangle())
      }.buttonStyle(.plain).help("Choose Audio Output").accessibilityIdentifier("duo.sound.outputs")
    }.padding(.horizontal, 10).padding(.vertical, 7).frame(height: 68).modifier(DuoSurface())
  }

  private var brightnessCard: some View {
    VStack(spacing: 5) {
      HStack(spacing: 6) {
        Image(systemName: "sun.max").frame(width: 18, height: 16)
        Text("Brightness").fontWeight(.medium)
        Spacer(minLength: 3)
        percent(display?.brightness)
      }.frame(height: 16)
      if let display, display.brightness != nil {
        DuoLevelSlider(value: Binding(get: { self.display?.brightness ?? 0 }, set: { brightness.set($0, display: display.id) }),
                       tint: .accentColor, enabled: true, label: display.name)
          .frame(height: 13)
      } else {
        Text("Brightness unavailable for this display").font(.system(size: 9)).foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, minHeight: 13, maxHeight: 13, alignment: .leading)
      }
      HStack(spacing: 6) {
        ForEach(DuoDisplayModes.Mode.allCases, id: \.self) { displayModeButton($0) }
      }.frame(maxWidth: .infinity).frame(height: 26)
        .contextMenu { Button("Open Display Settings") { DuoSettingsDestination.displays.open() } }
    }.padding(.horizontal, 10).padding(.vertical, 7).frame(height: 80).modifier(DuoSurface())
  }

  private func displayModeButton(_ mode: DuoDisplayModes.Mode) -> some View {
    let enabled = displayModes.states[mode]
    let status = enabled.map { $0 ? String(localized: "On") : String(localized: "Off") }
      ?? String(localized: "Unavailable on this Mac or display")
    return Button {
      Task {
        await displayModes.toggle(mode)
        if displayModes.error != nil { showsError = true }
      }
    } label: {
      HStack(spacing: 4) {
        Image(systemName: enabled == true ? "checkmark.circle.fill" : (enabled == nil ? "minus.circle" : "circle"))
          .font(.system(size: 10))
        Text(mode.title).lineLimit(1).minimumScaleFactor(0.8)
      }.font(.system(size: 10, weight: .medium))
        .foregroundStyle(enabled == true ? Color.accentColor : .secondary)
        .padding(.horizontal, 4).frame(maxWidth: .infinity).frame(height: 26)
        .background(enabled == true ? Color.accentColor.opacity(0.1) : Color.primary.opacity(0.035), in: Capsule())
        .contentShape(Rectangle())
    }.buttonStyle(.plain).disabled(enabled == nil || displayModes.busy)
      .help(mode.title + ": " + status)
      .accessibilityLabel(mode.title).accessibilityValue(status)
      .accessibilityIdentifier("duo.display.\(mode.rawValue)")
  }

  private var inputRow: some View {
    Button { input.refresh(); page = .input } label: {
      HStack(spacing: 7) {
        Text(input.shortName).font(.system(size: 10, weight: .semibold))
          .frame(width: 24, height: 22)
          .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
        Text("Input Source").font(.system(size: 10, weight: .medium)).fixedSize()
        Spacer(minLength: 0)
        Text(input.currentName).font(.system(size: 10)).lineLimit(1).foregroundStyle(.secondary)
        Image(systemName: "chevron.right").font(.system(size: 8, weight: .semibold)).foregroundStyle(.secondary)
      }.padding(.horizontal, 9).frame(height: 34).modifier(DuoSurface()).contentShape(Rectangle())
    }.buttonStyle(.plain).help("Choose Input Source").accessibilityIdentifier("duo.input.sources")
  }

  private var outputSelection: some View {
    VStack(spacing: 8) {
      selectionHeader("Output Device", refresh: metrics.refreshOutputs)
      Text("Select a device to play sound through.").font(.system(size: 9)).foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading).frame(height: 16)
      DuoChoiceList(items: metrics.outputDevices, emptyMessage: String(localized: "No audio output devices")) { device in
        DuoChoiceRow(title: device.name, symbol: "hifispeaker.fill", selected: metrics.audio.device == device.id) {
          metrics.selectOutput(device)
        }.accessibilityIdentifier("duo.output.\(device.id)")
      }
      selectionFooter(panel: .sound, panelLabel: "Open System Sound Panel", settings: .sound, settingsLabel: "Open Sound Settings")
    }
  }

  private var bluetoothSelection: some View {
    VStack(spacing: 8) {
      selectionHeader("Bluetooth", refresh: bluetooth.requestAccess)
      HStack {
        Text(bluetooth.busy ? String(localized: "Updating…") : bluetooth.status)
          .font(.system(size: 9)).foregroundStyle(.secondary)
        Spacer(minLength: 0)
        Toggle("Bluetooth", isOn: Binding(get: { bluetooth.powered == true }, set: bluetooth.setPowered))
          .labelsHidden().toggleStyle(.switch).controlSize(.mini).tint(.accentColor)
          .disabled(!bluetooth.canSetPower || bluetooth.busy)
          .accessibilityIdentifier("duo.bluetooth.power")
      }.frame(height: 16)
      wirelessList(height: $bluetoothListHeight) {
        if bluetooth.devices.isEmpty {
          wirelessEmptyMessage(bluetooth.emptyMessage)
        } else {
          wirelessSectionTitle("Paired Devices")
          ForEach(bluetooth.devices) { device in
            DuoChoiceRow(title: device.name, symbol: "wave.3.right", selected: device.connected,
                         actionLabel: bluetooth.busyDeviceID == device.id ? String(localized: "Updating…")
                           : (device.connected ? String(localized: "Disconnect") : String(localized: "Connect"))) {
              bluetooth.toggle(device)
            }.disabled(bluetooth.busy || bluetooth.powered != true)
              .accessibilityIdentifier("duo.bluetooth.\(device.id)")
          }
        }
      }
      selectionFooter(panel: .bluetooth, panelLabel: "Open System Bluetooth Panel", settings: .bluetooth, settingsLabel: "Open Bluetooth Settings")
    }
  }

  private var wifiSelection: some View {
    VStack(spacing: 8) {
      selectionHeader("Wi-Fi", refresh: wifi.requestAccess)
      HStack {
        Text(wifi.scanning ? String(localized: "Scanning for networks…") : wifiStatus)
          .font(.system(size: 9)).foregroundStyle(.secondary)
        Spacer(minLength: 0)
        wifiPowerToggle
      }.frame(height: 16)
      wirelessList(height: $wifiListHeight) {
        if metrics.wifiPowered != true || !wifi.authorized || wifi.networks.isEmpty {
          wirelessEmptyMessage(metrics.wifiPowered == false ? String(localized: "Turn on Wi-Fi to show nearby networks.") : wifi.emptyMessage)
        } else {
          if !knownNetworks.isEmpty {
            wirelessSectionTitle("Known Networks")
            ForEach(knownNetworks) { wifiNetworkRow($0) }
          }
          Button { showsOtherNetworks.toggle() } label: {
            HStack {
              Text("Other Networks").font(.system(size: 10, weight: .medium))
              Spacer(minLength: 0)
              Image(systemName: showsOtherNetworks ? "chevron.down" : "chevron.right")
                .font(.system(size: 9, weight: .semibold))
            }.foregroundStyle(.secondary).padding(.horizontal, 8).frame(height: 28)
              .contentShape(Rectangle())
          }.buttonStyle(.plain).accessibilityIdentifier("duo.wifi.otherNetworks")
            .accessibilityValue(showsOtherNetworks ? "Expanded" : "Collapsed")
          if showsOtherNetworks {
            if otherNetworks.isEmpty { wirelessEmptyMessage(String(localized: "No Wi-Fi networks found")) }
            else { ForEach(otherNetworks) { wifiNetworkRow($0) } }
          }
        }
      }
      HStack {
        if wifi.error != nil {
          Button { showsError = true } label: { Image(systemName: "exclamationmark.circle") }
            .buttonStyle(.plain).foregroundStyle(.orange).help("Action failed · Details")
        }
        Spacer(minLength: 0)
        Button {
          (wifi.authorized ? DuoSettingsDestination.wifi : DuoSettingsDestination.location).open()
        } label: {
          Label(wifi.authorized ? "Open Wi-Fi Settings" : "Open Location Settings", systemImage: "arrow.up.right")
        }.buttonStyle(.plain)
      }.font(.system(size: 9)).foregroundStyle(.secondary).frame(height: 22)
    }
  }

  private func wifiNetworkRow(_ network: DuoWiFi.Network) -> some View {
    DuoChoiceRow(title: network.name, symbol: network.secured ? "wifi.circle.fill" : "wifi", selected: network.connected,
                 actionLabel: wifiActionLabel(for: network)) {
      if network.connected || network.known || !network.secured {
        Task { _ = await wifi.connect(network) }
      } else if network.enterprise {
        DuoSettingsDestination.wifi.open()
      } else {
        selectedNetwork = network
        wifiPassword = ""
        page = .wifiPassword
      }
    }.disabled(wifi.busy || metrics.wifiBusy || metrics.wifiPowered != true)
      .accessibilityIdentifier("duo.wifi.\(network.id)")
  }

  private func wifiActionLabel(for network: DuoWiFi.Network) -> String {
    if wifi.busyNetworkID == network.id { return String(localized: "Updating…") }
    if network.connected { return String(localized: "Disconnect") }
    if network.enterprise && !network.known { return String(localized: "Open Settings") }
    return String(localized: "Connect")
  }

  private var wifiPasswordEntry: some View {
    VStack(spacing: 12) {
      HStack(spacing: 7) {
        Button { wifiPassword = ""; page = .wifi } label: {
          Image(systemName: "chevron.left").font(.system(size: 10, weight: .semibold)).frame(width: 22, height: 24)
            .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 7))
        }.buttonStyle(.plain).disabled(wifi.busy).help("Back").accessibilityLabel("Back")
          .accessibilityIdentifier("duo.wifi.password.back")
        Text(selectedNetwork?.name ?? "Wi-Fi").font(.system(size: 12, weight: .semibold)).lineLimit(1)
        Spacer(minLength: 0)
      }.frame(height: 24)
      Text("Enter the Wi-Fi password to connect.").font(.system(size: 10)).foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
      SecureField("Password", text: $wifiPassword).textFieldStyle(.roundedBorder)
        .disabled(wifi.busy).onSubmit(connectWiFiWithPassword)
        .accessibilityIdentifier("duo.wifi.password")
      Button(wifi.busy ? String(localized: "Connecting…") : String(localized: "Connect"), action: connectWiFiWithPassword)
        .disabled(wifiPassword.isEmpty || wifi.busy || metrics.wifiPowered != true)
        .accessibilityIdentifier("duo.wifi.connect")
      if let error = wifi.error {
        Text(error).font(.system(size: 10)).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }.onDisappear { wifiPassword = "" }
  }

  private func connectWiFiWithPassword() {
    guard let selectedNetwork, !wifiPassword.isEmpty, !wifi.busy, metrics.wifiPowered == true else { return }
    Task {
      if await wifi.connect(selectedNetwork, password: wifiPassword) { page = .wifi }
    }
  }

  private func wirelessList<Content: View>(height: Binding<CGFloat>, @ViewBuilder content: () -> Content) -> some View {
    ScrollView(.vertical) {
      VStack(spacing: 4, content: content)
        .frame(maxWidth: .infinity).fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { ceil($0.size.height) } action: { height.wrappedValue = $0 }
    }.scrollBounceBehavior(.basedOnSize).scrollIndicators(.hidden)
  }

  private func wirelessSectionTitle(_ title: LocalizedStringKey) -> some View {
    Text(title).font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8).frame(height: 18)
  }

  private func wirelessEmptyMessage(_ message: String) -> some View {
    Text(message).font(.system(size: 10)).foregroundStyle(.secondary)
      .multilineTextAlignment(.center).padding(18).frame(maxWidth: .infinity, minHeight: 70)
  }

  private var inputSelection: some View {
    VStack(spacing: 8) {
      selectionHeader("Input Source", refresh: input.refresh)
      Text("Select an input source to use immediately.").font(.system(size: 9)).foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading).frame(height: 16)
      DuoChoiceList(items: input.sources, emptyMessage: String(localized: "No input sources available")) { source in
        DuoChoiceRow(title: source.name, badge: source.badge, selected: input.currentID == source.id) {
          input.select(source)
        }.accessibilityIdentifier("duo.input.\(source.id)")
      }
      selectionFooter(panel: .inputSource, panelLabel: "Open System Input Menu", settings: .keyboard, settingsLabel: "Open Keyboard Settings")
    }
  }

  private func selectionHeader(_ title: LocalizedStringKey, refresh: @escaping () -> Void) -> some View {
    HStack(spacing: 7) {
      Button { page = .controls } label: {
        Image(systemName: "chevron.left").font(.system(size: 10, weight: .semibold)).frame(width: 22, height: 24)
          .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 7))
      }.buttonStyle(.plain).help("Back").accessibilityLabel("Back").accessibilityIdentifier("duo.back")
      Text(title).font(.system(size: 12, weight: .semibold))
      Spacer(minLength: 0)
      Button(action: refresh) { Image(systemName: "arrow.clockwise").frame(width: 24, height: 24) }
        .buttonStyle(.plain).foregroundStyle(.secondary).help("Refresh").accessibilityLabel("Refresh")
    }.frame(height: 24)
  }

  private func selectionFooter(panel: DuoSystemPanel, panelLabel: LocalizedStringKey,
                               settings: DuoSettingsDestination, settingsLabel: LocalizedStringKey) -> some View {
    HStack {
      if error != nil {
        Button { showsError = true } label: { Image(systemName: "exclamationmark.circle") }
          .buttonStyle(.plain).foregroundStyle(.orange).help("Action failed · Details")
      }
      Button { panel.open() } label: { Label("System Panel", systemImage: "macwindow") }
        .buttonStyle(.plain).help(panelLabel)
      Spacer(minLength: 0)
      Button { settings.open() } label: { Label("Open Settings", systemImage: "arrow.up.right") }
        .buttonStyle(.plain).help(settingsLabel)
    }.font(.system(size: 9)).foregroundStyle(.secondary).frame(height: 22)
  }

  private func percent(_ value: Double?) -> some View {
    Text(PercentText.whole(value.map { $0 * 100 }))
      .font(.system(size: 10, weight: .medium, design: .rounded))
      .monospacedDigit().foregroundStyle(.secondary).frame(width: 31, alignment: .trailing)
  }
}

/// Audio and input-source choices retain their fixed-size, paged layout.
private struct DuoChoiceList<Item: Identifiable, Row: View>: View {
  let items: [Item]
  let emptyMessage: String
  @ViewBuilder var row: (Item) -> Row
  @State private var requestedPage = 0
  private let pageSize = 5
  private var pageCount: Int { max(1, (items.count + pageSize - 1) / pageSize) }
  private var page: Int { min(requestedPage, pageCount - 1) }

  var body: some View {
    VStack(spacing: 4) {
      if items.isEmpty {
        Text(emptyMessage).font(.system(size: 10)).foregroundStyle(.secondary)
          .multilineTextAlignment(.center).padding(18).frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ForEach(Array(items.dropFirst(page * pageSize).prefix(pageSize))) { item in row(item) }
        Spacer(minLength: 0)
      }
      if pageCount > 1 {
        HStack {
          Button { requestedPage = page - 1 } label: { Image(systemName: "chevron.left").frame(width: 26, height: 20) }
            .disabled(page == 0).help("Previous Page").accessibilityLabel("Previous Page").accessibilityIdentifier("duo.previous")
          Spacer(minLength: 0)
          Text(verbatim: "\(page + 1) / \(pageCount)").monospacedDigit().foregroundStyle(.secondary)
          Spacer(minLength: 0)
          Button { requestedPage = page + 1 } label: { Image(systemName: "chevron.right").frame(width: 26, height: 20) }
            .disabled(page == pageCount - 1).help("Next Page").accessibilityLabel("Next Page").accessibilityIdentifier("duo.next")
        }.font(.system(size: 9)).buttonStyle(.plain).padding(.top, 4)
      }
    }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .onChange(of: items.count) { requestedPage = min(requestedPage, pageCount - 1) }
  }
}

private struct DuoChoiceRow: View {
  let title: String
  var symbol: String? = nil
  var badge: String? = nil
  let selected: Bool
  var actionLabel: String? = nil
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 7) {
        Group {
          if let badge { Text(badge).font(.system(size: 10, weight: .semibold)) }
          else if let symbol { Image(systemName: symbol).font(.system(size: 12)) }
        }.frame(width: 22, height: 22).foregroundStyle(selected ? Color.accentColor : .secondary)
        Text(title).font(.system(size: 10, weight: selected ? .medium : .regular)).lineLimit(1)
          .truncationMode(.middle)
        Spacer(minLength: 2)
        if let actionLabel {
          Text(actionLabel).font(.system(size: 9)).foregroundStyle(.secondary)
        } else if selected {
          Image(systemName: "checkmark").font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.accentColor)
        }
      }.padding(.horizontal, 8).frame(height: 34)
        .background(selected ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
        .contentShape(RoundedRectangle(cornerRadius: 8))
    }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
  }
}
