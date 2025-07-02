//
//  CpuUtil.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/2.
//

import Combine
import Foundation

class CpuUtil : ObservableObject {
  // 公开属性（直接暴露给视图）
  @Published private(set) var cpuUsage: Double = 0.0
  @Published private(set) var cpuSystem: Double = 0.0
  @Published private(set) var cpuUser: Double = 0.0
  @Published private(set) var cpuIdle: Double = 0.0
  
  // 私有状态
  private var previousLoad = host_cpu_load_info()
  private var timer: AnyCancellable?
  
  // 初始化
  init() {
    startMonitoring()
  }
  
  deinit {
    timer?.cancel()
  }
  
  // 监控控制
  private func startMonitoring() {
    timer = Timer.publish(every: 1, on: .main, in: .common)
      .autoconnect()
      .receive(on: DispatchQueue.global(qos: .utility))
      .sink { [weak self] _ in
        self?.updateCpuStats()
      }
  }
  
  // CPU 数据更新
  private func updateCpuStats() {
    guard let currentLoad = getHostCpuLoadInfo() else { return }
    
    // 计算 tick 差值
    let userDiff = Double(currentLoad.cpu_ticks.0 - previousLoad.cpu_ticks.0)
    let systemDiff = Double(currentLoad.cpu_ticks.1 - previousLoad.cpu_ticks.1)
    let idleDiff = Double(currentLoad.cpu_ticks.2 - previousLoad.cpu_ticks.2)
    let niceDiff = Double(currentLoad.cpu_ticks.3 - previousLoad.cpu_ticks.3)
    
    previousLoad = currentLoad
    
    let totalTicks = systemDiff + userDiff + idleDiff + niceDiff
    // 避免除零错误
    guard totalTicks > 0 else { return }
    
    // 计算百分比
    let system = (systemDiff / totalTicks) * 100
    let user = (userDiff / totalTicks) * 100
    let idle = (idleDiff / totalTicks) * 100
    
    // 主线程更新
    DispatchQueue.main.async { [weak self] in
      self?.cpuUsage = min(99.9, system + user)
      self?.cpuSystem = system
      self?.cpuUser = user
      self?.cpuIdle = idle
    }
  }
  
  // 安全的 Mach API 封装
  private func getHostCpuLoadInfo() -> host_cpu_load_info? {
    let count = MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size
    var size = mach_msg_type_number_t(count)
    let info = host_cpu_load_info_t.allocate(capacity: 1)
    
    defer {
      info.deallocate()
    }
    
    let result = info.withMemoryRebound(to: integer_t.self, capacity: count) {
      host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
    }
    
    guard result == KERN_SUCCESS, size == count else {
      print("Error getting CPU load: \(result)")
      return nil
    }
    
    return info.move()
  }
}
