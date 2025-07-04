//
//  FlowStack.swift
//  M-Tools
//
//  Created by 吴雲放 on 2023/9/22.
//

import SwiftUI

struct FlowStack<Content: View>: View {
    let content: () -> Content
    let spacing: CGSize

    public init(spacing: CGSize = .zero, @ViewBuilder content: @escaping () -> Content) {
        self.content = content
        self.spacing = spacing
    }
    
    public var body: some View {
        ZStack(alignment: .topLeading) {
            var available: CGFloat = 0
            var x: CGFloat = 0
            var y: CGFloat = 0
            Color.clear
                .frame(height: 0)
                .alignmentGuide(.top) { item in
                    available = item.width
                    x = 0
                    y = 0
                    return 0
                }
            
            content()
                .alignmentGuide(.leading) { item in
                    if x + item.width > available {
                        x = 0
                        y += item.height + spacing.height
                    }
                    let result = x
                    x += item.width + spacing.width
                    return -result
                }
                .alignmentGuide(.top) { _ in
                    -y
                }
        }
    }
}
