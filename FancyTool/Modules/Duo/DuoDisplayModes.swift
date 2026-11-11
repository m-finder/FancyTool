import AppKit
import Darwin
import ObjectiveC

@MainActor
final class DuoDisplayModes: ObservableObject {
  static let shared = DuoDisplayModes()

  enum Mode: String, CaseIterable {
    case dark, nightShift, trueTone

    var title: String {
      switch self {
      case .dark: String(localized: "Dark")
      case .nightShift: String(localized: "Night Shift")
      case .trueTone: String(localized: "True Tone")
      }
    }
  }

  struct Control {
    let read: () -> Bool?
    let write: (Bool) -> Bool
  }

  @Published private(set) var states: [Mode: Bool] = [:]
  @Published private(set) var busy = false
  @Published private(set) var error: String?
  private let controls: [Mode: Control]

  init(controls: [Mode: Control]? = nil) {
    self.controls = controls ?? Self.systemControls()
    refresh()
  }

  func refresh() {
    for mode in Mode.allCases { states[mode] = controls[mode]?.read() }
  }

  func toggle(_ mode: Mode) async {
    guard !busy else { return }
    error = nil
    refresh()
    guard let control = controls[mode], let current = states[mode] else {
      error = mode.title + ": " + String(localized: "Unavailable on this Mac or display")
      return
    }
    busy = true
    defer { busy = false }
    let requested = !current
    if control.write(requested) {
      // Display services can acknowledge a request before publishing its new state.
      for _ in 0..<10 {
        refresh()
        if states[mode] == requested { return }
        try? await Task.sleep(for: .milliseconds(100))
      }
    }
    refresh()
    if states[mode] != requested {
      error = mode.title + ": " + String(localized: "Unable to change display mode. Please try again or use Display Settings.")
    }
  }

  // Keep optional frameworks loaded for the lifetime of their objects and functions.
  private static let skyLight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
  private static let coreBrightness = dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_LAZY)

  private static func systemControls() -> [Mode: Control] {
    var controls: [Mode: Control] = [:]
    if let skyLight,
       let getter = dlsym(skyLight, "SLSGetAppearanceThemeLegacy"),
       let setter = dlsym(skyLight, "SLSSetAppearanceThemeNotifying") {
      let get = unsafeBitCast(getter, to: (@convention(c) () -> Bool).self)
      let set = unsafeBitCast(setter, to: (@convention(c) (Bool, Bool) -> Void).self)
      controls[.dark] = Control(read: { get() }, write: { enabled in
        set(enabled, true)
        return true
      })
    }
    guard coreBrightness != nil else { return controls }
    if let type = NSClassFromString("CBBlueLightClient") as? NSObject.Type {
      let client = type.init()
      if let supported = boolGetter(client, "supported"),
         let get = nightShiftGetter(client), let set = boolSetter(client) {
        controls[.nightShift] = Control(read: { supported() ? get() : nil }, write: set)
      }
    }
    if let type = NSClassFromString("CBTrueToneClient") as? NSObject.Type {
      let client = type.init()
      if let supported = boolGetter(client, "supported"),
         let available = boolGetter(client, "available"),
         let get = boolGetter(client, "enabled"), let set = boolSetter(client) {
        controls[.trueTone] = Control(read: { supported() && available() ? get() : nil }, write: set)
      }
    }
    return controls
  }

  private static func boolGetter(_ client: NSObject, _ name: String) -> (() -> Bool)? {
    let selector = NSSelectorFromString(name)
    guard let method = class_getInstanceMethod(type(of: client), selector),
          method_getNumberOfArguments(method) == 2,
          isBoolType(method_copyReturnType(method)) else { return nil }
    let call = unsafeBitCast(method_getImplementation(method),
      to: (@convention(c) (AnyObject, Selector) -> ObjCBool).self)
    return { call(client, selector).boolValue }
  }

  private static func boolSetter(_ client: NSObject) -> ((Bool) -> Bool)? {
    let selector = NSSelectorFromString("setEnabled:")
    guard let method = class_getInstanceMethod(type(of: client), selector),
          method_getNumberOfArguments(method) == 3,
          isBoolType(method_copyReturnType(method)),
          isBoolType(method_copyArgumentType(method, 2)) else { return nil }
    let call = unsafeBitCast(method_getImplementation(method),
      to: (@convention(c) (AnyObject, Selector, ObjCBool) -> ObjCBool).self)
    return { call(client, selector, ObjCBool($0)).boolValue }
  }

  private static func isBoolType(_ type: UnsafeMutablePointer<CChar>?) -> Bool {
    guard let type else { return false }
    defer { free(type) }
    return ["B", "c"].contains(String(cString: type))
  }

  private static func nightShiftGetter(_ client: NSObject) -> (() -> Bool?)? {
    let selector = NSSelectorFromString("getBlueLightStatus:")
    guard let method = class_getInstanceMethod(type(of: client), selector),
          method_getNumberOfArguments(method) == 3,
          isBoolType(method_copyReturnType(method)),
          let argument = method_copyArgumentType(method, 2) else { return nil }
    defer { free(argument) }
    // Check the private C layout before accessing its enabled/available fields.
    // BOOL encoding is B on arm64 and c on Intel; both layouts occupy 40 bytes.
    let encoding = String(cString: argument).replacingOccurrences(of: "c", with: "B")
    guard encoding == "^{?=BBBi{?={?=ii}{?=ii}}QB}" else { return nil }
    let call = unsafeBitCast(method_getImplementation(method),
      to: (@convention(c) (AnyObject, Selector, UnsafeMutableRawPointer) -> ObjCBool).self)
    return {
      let status = UnsafeMutableRawPointer.allocate(byteCount: 40, alignment: 8)
      defer { status.deallocate() }
      status.initializeMemory(as: UInt8.self, repeating: 0, count: 40)
      guard call(client, selector, status).boolValue,
            status.load(fromByteOffset: 32, as: UInt8.self) != 0 else { return nil }
      return status.load(fromByteOffset: 1, as: UInt8.self) != 0
    }
  }
}
