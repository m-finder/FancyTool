//
//  Runner.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/8/25.
//

import AppKit

final class Runner {

    static let shared = Runner()

    private var imageLayer: CALayer?
    private var currentFrames: [CGImage] = []
    private var currentFPS: Double = 60

    public var runner: RunnerModel? {
        RunnerHandler.shared.getRunnerById(AppState.shared.runnerId)
    }

    // MARK: - 取 Retina 帧
    private func reloadFrames() {
        guard let runner = runner else { currentFrames.removeAll(); return }
        _ = NSScreen.main?.backingScaleFactor ?? 2
        currentFrames = (0..<runner.frameNumber).compactMap { idx in
            runner.getImage(idx)
        }
    }

    // MARK: - 挂载
    func mount(to item: NSStatusItem) {
        guard let btn = item.button else { return }

        item.length = 22
        btn.frame = NSRect(x: 0, y: 0, width: 22, height: 22)

        reloadFrames()

        let layer = CALayer()
        layer.bounds = btn.bounds
        layer.position = CGPoint(x: btn.bounds.midX, y: btn.bounds.midY)
        layer.contentsGravity = .resizeAspect
        btn.wantsLayer = true
        btn.layer?.addSublayer(layer)
        imageLayer = layer

        applyAnimation(fps: currentFPS)
        item.menu = AppMenu.shared.getMenus()
    }

    // MARK: - 刷新速度
    func refresh(for item: NSStatusItem, usage: Double) {
        reloadFrames()
        let interval = 0.2 / max(1.0, min(20.0, usage / 5.0))
        let fps = 1.0 / interval
        print("fps \(fps)")
        applyAnimation(fps: fps)
    }

    private func applyAnimation(fps: Double) {
        guard let layer = imageLayer, !currentFrames.isEmpty else { return }
        let duration = Double(currentFrames.count) / fps

        let anim = CAKeyframeAnimation(keyPath: "contents")
        anim.values    = currentFrames
        anim.keyTimes  = (0..<currentFrames.count).map {
            NSNumber(value: Double($0) / Double(currentFrames.count))
        }
        anim.duration  = duration
        anim.repeatCount = .infinity
        anim.calculationMode = .discrete
        anim.isRemovedOnCompletion = false

        layer.removeAnimation(forKey: "cpu")
        layer.add(anim, forKey: "cpu")
    }
}
