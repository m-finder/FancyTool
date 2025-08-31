//
//  TaskManager.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/8/30.
//

import Foundation
import Combine

class TaskManager {
  static let shared = TaskManager()
  
  private var tasks: [String: Task] = [:]
  private var timer: DispatchSourceTimer?
  private let queue = DispatchQueue(label: "com.fancytool.task", qos: .utility)
  private var nextWakeTime: Date = Date()
 
  private init() {
    startMainTimer()
  }
  
  // 任务定义
  struct Task {
    let id: String
    var interval: TimeInterval
    let queue: DispatchQueue
    let action: () -> Void
    var lastRun: Date = Date.distantPast
    var nextRun: Date = Date.distantPast
    
    init(id: String, interval: TimeInterval, queue: DispatchQueue, action: @escaping () -> Void) {
      self.id = id
      self.interval = interval
      self.queue = queue
      self.action = action
      self.nextRun = Date().addingTimeInterval(interval)
    }
  }
  
  // 添加任务
  func addTask(
    id: String,
    interval: TimeInterval,
    queue: DispatchQueue = DispatchQueue.main,
    action: @escaping () -> Void
  ) {
    self.queue.sync {
      let task = Task(id: id, interval: interval, queue: queue, action: action)
      tasks[id] = task
      rescheduleTimer()
    }
  }
  
  // 移除任务
  func removeTask(id: String) {
    self.queue.sync {
      tasks.removeValue(forKey: id)
      rescheduleTimer()
    }
  }
  
  // 更新任务间隔
  func updateTaskInterval(id: String, newInterval: TimeInterval) {
    self.queue.sync {
      if var task = tasks[id] {
        task.interval = newInterval
        task.nextRun = task.lastRun.addingTimeInterval(newInterval)
        tasks[id] = task
        rescheduleTimer()
      }
    }
  }
  
  // 启动主定时器
  private func startMainTimer() {
    rescheduleTimer()
  }
  
  // 重新安排定时器
  private func rescheduleTimer() {
    timer?.cancel()
    
    // 如果没有任务，不需要定时器
    guard !tasks.isEmpty else {
      timer = nil
      return
    }
    
    // 找到下一个需要执行的任务时间
    let nextExecutionTime = tasks.values
      .map { $0.nextRun }
      .min() ?? Date().addingTimeInterval(1.0)
    
    // 计算距离下一个任务的时间
    let timeInterval = max(0.1, nextExecutionTime.timeIntervalSince(Date()))
    
    // 创建新的定时器
    timer = DispatchSource.makeTimerSource(queue: queue)
    timer?.schedule(
      deadline: .now() + timeInterval,
      leeway: .milliseconds(Int(timeInterval * 1000 * 0.5))
    )
    timer?.setEventHandler { [weak self] in
      self?.executeTasks()
      self?.rescheduleTimer()
    }
    timer?.resume()

    nextWakeTime = nextExecutionTime
  }
  
  // 执行任务
  private func executeTasks() {
    let now = Date()
    
    for (id, var task) in tasks {
      if now >= task.nextRun {
        task.lastRun = now
        task.nextRun = now.addingTimeInterval(task.interval)
        tasks[id] = task
        
        task.queue.async {
          task.action()
        }
      }
    }
  }
  
  deinit {
    timer?.cancel()
  }
}
