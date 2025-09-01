//
//  Rounder.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/8/23.
//

import Foundation
import SwiftUI
import AppKit
import Combine

class Rounder {
    
    // MARK: - Singleton
    public static let shared = Rounder()
    
    // MARK: - Properties
    private var windows: [NSWindow] = []
    private var cancellables = Set<AnyCancellable>()
    private let state = AppState.shared
    
    // MARK: - Initialization
    private init() {
        setupObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup Methods
    private func setupObservers() {
        // 监听屏幕参数变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    // MARK: - Screen Change Handler
    @objc private func handleScreenChange(_ notification: Notification) {
        // 延迟执行以确保系统完成屏幕配置更新
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.mount()
        }
    }
    
    // MARK: - Public Methods
    public func mount() {
        unmount()
        
        for screen in NSScreen.screens {
            createWindow(for: screen)
        }
    }
    
    public func unmount() {
        windows.forEach { $0.close() }
        windows.removeAll()
    }
    
    public func refresh() {
        for window in windows {
            guard let contentView = window.contentView as? RounderView else { continue }
            contentView.radius = state.radius
            contentView.setNeedsDisplay(contentView.bounds)
        }
    }
    
    // MARK: - Helper Methods
    private func createWindow(for screen: NSScreen) {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )
        
        configure(window: window)
        setupContentView(for: window, screen: screen)
        
        window.orderFrontRegardless()
        windows.append(window)
    }
    
    private func configure(window: NSWindow) {
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.alphaValue = 1
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.stationary, .ignoresCycle, .canJoinAllSpaces, .fullScreenAuxiliary]
        window.level = .screenSaver
    }
    
    private func setupContentView(for window: NSWindow, screen: NSScreen) {
        let contentView = RounderView(
            frame: NSRect(origin: .zero, size: screen.frame.size),
            radius: state.radius
        )
        window.contentView = contentView
    }
}

