import AppKit
import Darwin

/// DisplayServices is optional: unsupported displays keep a system-settings fallback.
@MainActor
final class DuoBrightness: ObservableObject {
  static let shared = DuoBrightness()
  struct Display: Identifiable {
    let id: CGDirectDisplayID
    let name: String
    var brightness: Double?
  }
  private typealias Get = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
  private typealias Set = @convention(c) (CGDirectDisplayID, Float) -> Int32
  private let library = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)
  @Published private(set) var displays: [Display] = []
  @Published private(set) var error: String?
  private var getter: Get? {
    guard let library, let symbol = dlsym(library, "DisplayServicesGetBrightness") else { return nil }
    return unsafeBitCast(symbol, to: Get.self)
  }
  private var setter: Set? {
    guard let library, let symbol = dlsym(library, "DisplayServicesSetBrightness") else { return nil }
    return unsafeBitCast(symbol, to: Set.self)
  }
  func refresh() {
    displays = NSScreen.screens.compactMap { screen in
      guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return nil }
      var value: Float = 0
      let supported = getter?(id, &value) == 0 && setter != nil && value.isFinite && (0...1).contains(value)
      return Display(id: id, name: screen.localizedName, brightness: supported ? Double(value) : nil)
    }
  }
  func set(_ value: Double, display: CGDirectDisplayID) {
    guard value.isFinite, let setter else { return }
    if setter(display, Float(min(1, max(0, value)))) == 0 {
      error = nil
      if let index = displays.firstIndex(where: { $0.id == display }) { displays[index].brightness = value }
    } else {
      error = String(localized: "Brightness control unavailable.")
      refresh()
    }
  }
}
