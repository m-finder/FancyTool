//
//  CpuUtil.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/2.
//
import Combine
import Foundation

class CpuUtil: ObservableObject {
  
  @Published private(set) var cpuUsage: Double = 0.0
  
  private var previousLoad = host_cpu_load_info()
  private let updateQueue = DispatchQueue(label: "com.fancytool.cpu-monitor", qos: .utility)
  
  init(updateInterval: TimeInterval = 5) {
    if !AppState.shared.runnerId.isEmpty{
      startMonitoring(interval: updateInterval)
    }else{
      TaskManager.shared.removeTask(id: "cpu_monitor")
    }
  }
  
  deinit {
    TaskManager.shared.removeTask(id: "cpu_monitor")
  }
  
  public func startMonitoring(interval: TimeInterval) {
    TaskManager.shared.addTask(id: "cpu_monitor", interval: 5.0, queue: updateQueue) { [weak self] in
      self?.updateCpuStats()
    }
  }
  
  private func updateCpuStats() {
    guard let currentLoad = getHostCpuLoadInfo() else { return }
    
    let userDiff = Double(currentLoad.cpu_ticks.0 - previousLoad.cpu_ticks.0)
    let systemDiff = Double(currentLoad.cpu_ticks.1 - previousLoad.cpu_ticks.1)
    let idleDiff = Double(currentLoad.cpu_ticks.2 - previousLoad.cpu_ticks.2)
    let niceDiff = Double(currentLoad.cpu_ticks.3 - previousLoad.cpu_ticks.3)
    
    previousLoad = currentLoad
    
    let totalTicks = systemDiff + userDiff + idleDiff + niceDiff
    guard totalTicks > 0 else { return }
 
    DispatchQueue.main.async { [weak self] in
      self?.cpuUsage = min(99.9, (systemDiff + userDiff) / totalTicks * 100)
    }
  }
  
  private func getHostCpuLoadInfo() -> host_cpu_load_info? {
    var size = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
    var info = host_cpu_load_info()
    
    let result = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
        host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
      }
    }
    
    guard result == KERN_SUCCESS else {
      print("Error getting CPU load: \(result)")
      return nil
    }
    
    return info
  }
}
