//
//  CpuUtil.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/2.
//

import Foundation

@MainActor
class CpuUtil: ObservableObject {
  
  public static var shared = CpuUtil()
  
  public var usage: Double = 0.0
  private var previousLoad = host_cpu_load_info()
 
  public func refresh() {
    guard let currentLoad = getCurrentInfo() else { return }
    
    let userDiff = Double(currentLoad.cpu_ticks.0 - previousLoad.cpu_ticks.0)
    let systemDiff = Double(currentLoad.cpu_ticks.1 - previousLoad.cpu_ticks.1)
    let idleDiff = Double(currentLoad.cpu_ticks.2 - previousLoad.cpu_ticks.2)
    let niceDiff = Double(currentLoad.cpu_ticks.3 - previousLoad.cpu_ticks.3)
    
    previousLoad = currentLoad
    
    let totalTicks = systemDiff + userDiff + idleDiff + niceDiff
    guard totalTicks > 0 else { return }
 
    self.usage = min(99.9, (systemDiff + userDiff) / totalTicks * 100)
  }
  
  private func getCurrentInfo() -> host_cpu_load_info? {
    var size = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
    var info = host_cpu_load_info()
    
    let result = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
        host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
      }
    }

    return result == KERN_SUCCESS ? info : nil
  }
}
