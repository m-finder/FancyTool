//
//  CpuUtil.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/2.
//

import Foundation
import SystemConfiguration

@MainActor
class NetworkUtil: ObservableObject {
  
  public static var shared = NetworkUtil()
  
  public var upload:   String = "0 B/s"
  public var download: String = "0 B/s"
  public  var ip:       String = "127.0.0.1"
  
  // 仅内部用：上一次累计值 + 时间戳
  private var prev: (up: Int64, down: Int64, time: Date)?
  
  public func refresh() {
    guard let cur = currentInfo() else { return }
    let now = Date()
    
    if let p = prev {
      let dt = now.timeIntervalSince(p.time)
      guard dt > 0 else { return }
      let upSp   = Double(cur.bytes.up   - p.up)   / dt
      let downSp = Double(cur.bytes.down - p.down) / dt
      upload   = format(upSp)
      download = format(downSp)
    }
    ip = cur.ip
    prev = (cur.bytes.up, cur.bytes.down, now)
  }
  
  // MARK: - 底层采集
  private struct Info {
    let bytes: (up: Int64, down: Int64)
    let ip: String
  }
  
  private func currentInfo() -> Info? {
    let iface = primaryInterface() ?? "en0"
    var up: Int64 = 0, down: Int64 = 0, ipStr = "127.0.0.1"
    
    var ptr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ptr) == 0 else { return nil }
    var cur = ptr
    
    while cur != nil {
      defer { cur = cur?.pointee.ifa_next }
      let name = String(cString: cur!.pointee.ifa_name)
      guard name == iface else { continue }
      
      // 字节累计
      if let data = unsafeBitCast(
        cur?.pointee.ifa_data,
        to: UnsafeMutablePointer<if_data>?.self
      ) {
        up   = Int64(data.pointee.ifi_obytes)
        down = Int64(data.pointee.ifi_ibytes)
      }
      
      // IPv4
      var addr = cur!.pointee.ifa_addr.pointee
      guard addr.sa_family == UInt8(AF_INET) else { continue }
      var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
      getnameinfo(&addr, socklen_t(addr.sa_len),
                  &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
      let len = host.firstIndex(of: 0) ?? host.count
      ipStr = String(decoding: host[..<len].map(UInt8.init(bitPattern:)), as: UTF8.self)
    }
    freeifaddrs(ptr)
    return Info(bytes: (up: up, down: down), ip: ipStr)
  }
  
  private func primaryInterface() -> String? {
    let store = SCDynamicStoreCreate(nil, "util" as CFString, nil, nil)
    let key   = SCDynamicStoreKeyCreateNetworkGlobalEntity(
      nil,
      kSCDynamicStoreDomainState,
      kSCEntNetIPv4
    )
    guard let dict = SCDynamicStoreCopyValue(store, key) as? [String: Any],
          let name = dict[kSCDynamicStorePropNetPrimaryInterface as String] as? String
    else { return nil }
    return name
  }
  
  // MARK: - 单位换算
  private func format(_ bps: Double) -> String {
    let KB = 1024.0, MB = KB * 1024, GB = MB * 1024
    switch bps {
    case 0..<KB: return String(format: "%.2f B/s", bps)
    case KB..<MB: return String(format: "%.2f KB/s", bps / KB)
    case MB..<GB: return String(format: "%.2f MB/s", bps / MB)
    default: return String(format: "%.2f GB/s", bps / GB)
    }
  }
}
