//
//  AppInstanceLock.swift
//  FancyTool
//

import Darwin
import Foundation

/// Keeps two copies of the same app build from writing the same local files.
/// `flock` is released automatically when the process terminates, including
/// abnormal termination, unlike a marker file that can be left behind.
@MainActor
final class AppInstanceLock {
  static let shared = AppInstanceLock()

  private var fileDescriptor: Int32 = -1

  private init() {}

  func acquire() -> Bool {
    guard fileDescriptor == -1 else { return true }

    do {
      let lockURL = try FancyToolFileStore.rootDirectory().appendingPathComponent("instance.lock")
      let descriptor = open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
      guard descriptor >= 0 else { return false }

      guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
        close(descriptor)
        return false
      }

      fileDescriptor = descriptor
      return true
    } catch {
      print("Failed to create FancyTool instance lock: \(error)")
      return false
    }
  }

  deinit {
    guard fileDescriptor >= 0 else { return }
    flock(fileDescriptor, LOCK_UN)
    close(fileDescriptor)
  }
}
