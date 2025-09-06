//
//  ShimmerLayer.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/9/6.
//

import QuartzCore
import SwiftUI

final class ShimmerLayer: CALayer {

    private let gradientLayer = CAGradientLayer()
    private let animationKey = "shimmer"

    override init() {
        super.init()
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        gradientLayer.colors = [
          NSColor.clear.cgColor,
          NSColor.white.withAlphaComponent(0.8).cgColor,
          NSColor.clear.cgColor
        ]
        gradientLayer.locations = [0.0, 0.5, 1.0]
        gradientLayer.startPoint = CGPoint(x: -1.0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 0.0, y: 0.5)
        gradientLayer.frame = bounds
        addSublayer(gradientLayer)
    }

    override func layoutSublayers() {
        super.layoutSublayers()
        gradientLayer.frame = bounds
    }

    func startAnimation() {
        let animation = CABasicAnimation(keyPath: "transform.translation.x")
        animation.fromValue = -bounds.width
        animation.toValue = bounds.width
        animation.duration = 2.5
        animation.repeatCount = .infinity
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards
        gradientLayer.add(animation, forKey: animationKey)
    }

    func stopAnimation() {
        gradientLayer.removeAnimation(forKey: animationKey)
    }
}
