//
//  ColorModel.swift
//  M-Tools
//
//  Created by 吴雲放 on 2023/9/23.
//

import SwiftUI
import Foundation

class ColorUtil: ObservableObject{
  
  static let shared = ColorUtil()
  
  private let colors: [[Color]] = [
    [Color(hex: 0xF5E597), Color(hex: 0x66A09B)],
    [Color(hex: 0xB4A9EA), Color(hex: 0xE9C8F1)],
    [Color(hex: 0x4300B1), Color(hex: 0xA531DC)],
    [Color(hex: 0xD02020), Color(hex: 0xFF896D)],
    [Color(hex: 0x0017E4), Color(hex: 0x3793FF)],
    [Color(hex: 0xFF7A00), Color(hex: 0xFFD439)],
    [Color(hex: 0x4B73FF), Color(hex: 0x7CF7FF)],
    [Color(hex: 0xFF7EC7), Color(hex: 0xFFED46)],
    [Color(hex: 0x39A0FF), Color(hex: 0x8FFF85)],
    [Color(hex: 0xD079EE), Color(hex: 0x8A88FB)],
    [Color(hex: 0x8B8B8B), Color(hex: 0xEAEAEA)],
    [Color(hex: 0x4DEF8E), Color(hex: 0xFFEB3A)],
    [Color(hex: 0x181818), Color(hex: 0x565656)],
    [Color(hex: 0x7B6AE0), Color(hex: 0xFFBB89)],
    [Color(hex: 0xFFB800), Color(hex: 0xFFF500)],
    [Color(hex: 0xFF9DE4), Color(hex: 0xFFEAF6)],
    [Color(hex: 0x00552C), Color(hex: 0x00B960)],
    [Color(hex: 0xAD8211), Color(hex: 0xFFE6A4)],
    [Color(hex: 0x4A879A), Color(hex: 0xC5EDF5)],
    [Color(hex: 0xDFD1C5), Color(hex: 0xFFF6EB)],
    [Color(hex: 0x4D6AD0), Color(hex: 0xFF9D7E)],
    [Color(hex: 0xFF6C6C), Color(hex: 0xDD7BFF)],
    [Color(hex: 0x8FB85B), Color(hex: 0xE0FF87)],
    [Color(hex: 0xFF62C0), Color(hex: 0xFFDC99)],
    [Color(hex: 0x8DA2EE), Color(hex: 0xDDE4FF)],
    [Color(hex: 0x5CB67F), Color(hex: 0x97E8B5)],
    [Color(hex: 0x001C63), Color(hex: 0x24CFC5)],
    [Color(hex: 0x063CFF), Color(hex: 0xFF3F3F)],
    [Color(hex: 0x0E2C5E), Color(hex: 0x5D85A6)],
    [Color(hex: 0x6F00B3), Color(hex: 0xDEB5FF)],
    [Color(hex: 0x456EFF), Color(hex: 0xFF5EEF)],
    [Color(hex: 0x616566), Color(hex: 0xAFCCCB)],
    [Color(hex: 0x6B0013), Color(hex: 0x4063BC)],
    [Color(hex: 0xFF00B8), Color(hex: 0xFFF500)],
    [Color(hex: 0x0F213E), Color(hex: 0xFF5E98)],
    [Color(hex: 0xE20000), Color(hex: 0xFFC328)],
    [Color(hex: 0x27B643), Color(hex: 0xFFE70B)],
    [Color(hex: 0xB1FF96), Color(hex: 0xFFADF7)],
    [Color(hex: 0x133114), Color(hex: 0x61C695)],
    [Color(hex: 0xFFA4F6), Color(hex: 0xB7DCFF)],
    [Color(hex: 0xFF7A00), Color(hex: 0x9F25FF)],
    [Color(hex: 0x00576A), Color(hex: 0x5EE2FF)],
    [Color(hex: 0x470000), Color(hex: 0xFF0000)],
    [Color(hex: 0x0B0A47), Color(hex: 0x4643DF)],
    [Color(hex: 0x19087E), Color(hex: 0xD7003A)],
    [Color(hex: 0x9F3311), Color(hex: 0xFADD76)],
    [Color(hex: 0xAD00FE), Color(hex: 0x00E0EE)],
    [Color(hex: 0x88069D), Color(hex: 0xD0004B)],
    [Color(hex: 0x418CB7), Color(hex: 0xFF8570)],
    [Color(hex: 0x000000), Color(hex: 0xB9A14C)],
  ]
  
  public func getColor (index: Int) -> [Color] {
    if index > colors.count {
      return [.white]
    }
    return colors[index]
  }
  
  public func getColors () -> [[Color]] {
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
