//
//  ColorModel.swift
//  M-Tools
//
//  Created by 吴雲放 on 2023/9/23.
//

import SwiftUI
import Foundation

class ColorModel: ObservableObject{
    
    let colors: [[Color]] = [
        [.white],
        [Color(hex: 0xa5e0ff), Color(hex: 0x7cbce6), Color(hex: 0x5398cd)],
        [Color(hex: 0xa4133c), Color(hex: 0xc9184a), Color(hex: 0xff4d6d)],
        [Color(hex: 0xcc5803), Color(hex: 0xe2711d), Color(hex: 0xff9505)],
        [Color(hex: 0xd4d700), Color(hex: 0xdddf00), Color(hex: 0xeeef20)],
        [Color(hex: 0x2b9348), Color(hex: 0x55a630), Color(hex: 0x80b918)],
        [Color(hex: 0x57cc99), Color(hex: 0x80ed99), Color(hex: 0xc7f9cc)],
        [Color(hex: 0x3f37c9), Color(hex: 0x4361ee), Color(hex: 0x4895ef)],
        [Color(hex: 0x9d4edd), Color(hex: 0xc77dff), Color(hex: 0xe0aaff)],
    ]
    
    func getColor (index: Int) -> [Color] {
        if index > colors.count {
            return [.white]
        }
        return colors[index]
    }
    
    func getColors () -> [[Color]] {
        return colors
    }
}

// hex color
extension Color {
    init(hex: Int, opacity: Double = 1.0) {
        let red = Double((hex & 0xff0000) >> 16) / 255.0
        let green = Double((hex & 0xff00) >> 8) / 255.0
        let blue = Double((hex & 0xff) >> 0) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
