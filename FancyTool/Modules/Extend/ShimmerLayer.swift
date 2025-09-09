//
//  ShimmerLayer.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/9/6.
//

//
//  ShimmerLayer.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/9/6.
//

import SwiftUI
import AppKit

final class ShimmerLayerBackedView: NSView {
    private let container = CALayer()
    private let backgroundLayer = CALayer()
    private let highlightLayer = CAGradientLayer()
    private let textMaskLayer = CATextLayer()
    
    private var bandSize: CGFloat = 0.01
    private var isAnimating = false
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        layer = CALayer()
        layer?.contentsScale = scale
        
        container.contentsScale = scale
        layer?.addSublayer(container)
        
        backgroundLayer.contentsScale = scale
        backgroundLayer.backgroundColor = NSColor.labelColor.cgColor
        container.addSublayer(backgroundLayer)
        
        highlightLayer.contentsScale = scale
        highlightLayer.startPoint = CGPoint(x: -1, y: 0.5)
        highlightLayer.endPoint = CGPoint(x: 2, y: 0.5)
        highlightLayer.colors = [
            NSColor.clear.cgColor,
            NSColor.white.withAlphaComponent(0.9).cgColor,
            NSColor.clear.cgColor
        ]
        highlightLayer.locations = [-0.3, 0.0, 0.3]
        container.addSublayer(highlightLayer)
        
        textMaskLayer.contentsScale = scale
        textMaskLayer.alignmentMode = .center
        textMaskLayer.truncationMode = .end
        textMaskLayer.isWrapped = false
        textMaskLayer.foregroundColor = NSColor.white.cgColor
        textMaskLayer.backgroundColor = NSColor.clear.cgColor
        textMaskLayer.rasterizationScale = scale
        textMaskLayer.allowsEdgeAntialiasing = true
        textMaskLayer.allowsFontSubpixelQuantization = true
        
        container.mask = textMaskLayer
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func layout() {
        super.layout()
        let b = bounds
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer?.frame = b
        container.frame = b
        backgroundLayer.frame = b
        highlightLayer.frame = b
        textMaskLayer.frame = b
        CATransaction.commit()
    }
    
    func configure(
        text: String,
        font: NSFont,
        baseColor: NSColor,
        rainbow: Bool,
        bandSize: CGFloat,
        customGradient: [NSColor]?
    ) {
        self.bandSize = bandSize
        
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attr = NSAttributedString(
            string: text.isEmpty ? " " : text,
            attributes: [
                .font: font,
                .foregroundColor: NSColor.white,
                .paragraphStyle: paragraph
            ]
        )
        textMaskLayer.string = attr
        
        backgroundLayer.backgroundColor = baseColor.cgColor
        
        if let custom = customGradient, !custom.isEmpty {
            highlightLayer.colors = custom.map { $0.cgColor }
        } else {
            if rainbow {
                highlightLayer.colors = [
                    NSColor.clear.cgColor,
                    NSColor.systemOrange.withAlphaComponent(0.95).cgColor,
                    NSColor.systemBlue.withAlphaComponent(0.95).cgColor,
                    NSColor.systemGreen.withAlphaComponent(0.95).cgColor,
                    NSColor.clear.cgColor
                ]
            } else {
                highlightLayer.colors = [
                    NSColor.clear.cgColor,
                    NSColor.clear.cgColor,
                    NSColor.white.withAlphaComponent(0.95).cgColor,
                    NSColor.clear.cgColor,
                    NSColor.clear.cgColor
                ]
            }
        }
        
        // 彩虹 5 色标 ↔ 5 段 locations
        if rainbow && highlightLayer.colors?.count == 5 {
//            highlightLayer.locations = [0.0, 0.25, 0.5, 0.75, 1.0]
          highlightLayer.locations = [0.45, 0.475, 0.5, 0.525, 0.55]
        } else {
          highlightLayer.locations = [-bandSize * 0.05, 0, bandSize * 0.05] as [NSNumber]
        }
    }
    
    func setActive(_ active: Bool, duration: CFTimeInterval) {
        if active {
            startAnimating(duration: duration)
            highlightLayer.isHidden = false
        } else {
            stopAnimating()
            highlightLayer.isHidden = true
        }
    }
    
    private func startAnimating(duration: CFTimeInterval) {
        guard !isAnimating else { return }
        isAnimating = true
        
        let count = highlightLayer.colors?.count ?? 3
        let step = 1.0 / max(CGFloat(count - 1), 1)
        let from = (0..<count).map { NSNumber(value: Float($0) * Float(step) - Float(bandSize)) }
        let to   = (0..<count).map { NSNumber(value: Float($0) * Float(step) + Float(1 - bandSize)) }

        let anim = CABasicAnimation(keyPath: "locations")
        anim.fromValue = from
        anim.toValue = to
        anim.duration = duration
        anim.timingFunction = CAMediaTimingFunction(name: .linear)
        anim.repeatCount = .infinity
        anim.isRemovedOnCompletion = false
        
        highlightLayer.add(anim, forKey: "shimmer.locations")
    }
    
    private func stopAnimating() {
        guard isAnimating else { return }
        isAnimating = false
        highlightLayer.removeAnimation(forKey: "shimmer.locations")
    }
}

struct LayerShimmerText: NSViewRepresentable {
    var text: String
    var font: NSFont
    var baseColor: NSColor = .labelColor
    var active: Bool = true
    var rainbow: Bool = true
    var bandSize: CGFloat = 0.01
    var duration: CFTimeInterval = 3.0
    var gradientColors: [NSColor]? = nil
    
    func makeNSView(context: Context) -> ShimmerLayerBackedView {
        let v = ShimmerLayerBackedView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.setFrameSize(NSSize(width: 10, height: 18))
        return v
    }
    
    func updateNSView(_ nsView: ShimmerLayerBackedView, context: Context) {
        nsView.configure(
            text: text,
            font: font,
            baseColor: baseColor,
            rainbow: rainbow,
            bandSize: bandSize,
            customGradient: gradientColors
        )
        nsView.setActive(active, duration: duration)
    }
}
