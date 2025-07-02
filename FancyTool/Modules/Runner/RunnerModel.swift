//
//  RunnerModel.swift
//  FancyTool
//
//  Created by 吴雲放 on 2025/7/2.
//

import Foundation
import SwiftData
import AppKit
import CoreGraphics

@Model
class RunnerModel {
  
  @Attribute(.unique) var id: UUID
  var type: String
  var frame_number: Int
  var data: Data
  
  // 初始化
  init(id: UUID, type: String, frame_number: Int, data: Data) {
    self.id = id
    self.type = type
    self.frame_number = frame_number
    self.data = data
  }
  
  // 默认 Runner 配置
//  static let defaultRunners: [String: (String, String)] = [
//    "mario": ("A1AF9595-F3FC-4A4F-A134-8F9CED4B761D", "default"),
//    "hello": ("A2AF9595-F3FC-4A4F-A134-8F9CED4B767D", "default"),
//  ]
  
  // GIF 处理功能
//  static var defaultImage = NSImage(named: "AppIcon")?.cgImage(forProposedRect: nil, context: nil, hints: nil)
//  static var imgCache = [RunnerModel: [Int: CGImage]]()
  
  // 获取图片数据
//  private func getImageOptions() -> CFDictionary {
//    return [
//      kCGImageSourceShouldCache: true,
//      kCGImageSourceTypeIdentifierHint: "public.gif"
//    ] as CFDictionary
//  }
//  
//  // 获取图片来源
//  private func getCGImageSource(_ data: Data?) -> CGImageSource? {
//    guard let rawData = data else { return nil }
//    return CGImageSourceCreateWithData(rawData as CFData, getImageOptions())
//  }
//  
//  // 获取图片帧数
//  func getRealFrameCount() -> Int {
//    guard let imageSrc = getCGImageSource(data) else { return 0 }
//    return CGImageSourceGetCount(imageSrc)
//  }
  
  // 设置 GIF
//  func setGIF(data: Data) -> Bool {
//    let num = getRealFrameCount()
//    guard num > 0 else { return false }
//    self.frame_number = num
//    self.data = data
//    RunnerModel.imgCache[self] = nil
//    return true
//  }
  
  // 获取图片
//  func getImage(_ index: Int) -> CGImage {
//    var safeIndex = index
//    
//    if RunnerModel.imgCache[self] == nil {
//      RunnerModel.imgCache[self] = [:]
//    }
//    
//    if RunnerModel.imgCache[self]?[safeIndex] == nil {
//      if safeIndex >= self.frame_number || safeIndex < 0 {
//        safeIndex = 0
//      }
//      
//      guard let img_src = getCGImageSource(self.data),
//            let img = CGImageSourceCreateImageAtIndex(img_src, safeIndex, getImageOptions())
//      else {
//        return RunnerModel.defaultImage ?? createFallbackImage()
//      }
//      
//      RunnerModel.imgCache[self]?[safeIndex] = img
//    }
//    
//    return RunnerModel.imgCache[self]?[safeIndex] ?? RunnerModel.defaultImage ?? createFallbackImage()
//  }
  
//  private func createFallbackImage() -> CGImage {
//    let size = CGSize(width: 100, height: 100)
//    let colorSpace = CGColorSpaceCreateDeviceRGB()
//    let context = CGContext(data: nil,
//                            width: Int(size.width),
//                            height: Int(size.height),
//                            bitsPerComponent: 8,
//                            bytesPerRow: 0,
//                            space: colorSpace,
//                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
//    
//    context.setFillColor(NSColor.systemRed.cgColor)
//    context.fill(CGRect(origin: .zero, size: size))
//    
//    return context.makeImage()!
//  }
//  
//  // 数据初始化
//  static func setupDefaultData(in context: ModelContext) {
//    // 填充默认 Runner
//    fillWithDefaultRunner(context: context)
//    
//    // 创建默认 DIY Runner
//    createDefaultDiyRunner(context: context)
//    
//    // 保存更改
//    try? context.save()
//  }
//  
//  private static func fillWithDefaultRunner(context: ModelContext) {
//    guard let urls = Bundle.main.urls(forResourcesWithExtension: "gif", subdirectory: nil) else { return }
//    
//    for url in urls {
//      let name = url.deletingPathExtension().lastPathComponent
//      guard let conf = defaultRunners[name],
//            let uuid = UUID(uuidString: conf.0),
//            let gifData = try? Data(contentsOf: url)
//      else { continue }
//      
//      // 检查是否已存在
//      let exists = (try? context.fetchCount(
//        FetchDescriptor<RunnerModel>(
//          predicate: #Predicate { $0.id == uuid }
//        )
//      )) ?? 0 > 0
//      
//      if !exists {
//        let runner = RunnerModel(
//          id: uuid,
//          type: conf.1,
//          frame_number: 0, // 稍后设置
//          data: gifData
//        )
//        _ = runner.setGIF(data: gifData)
//        context.insert(runner)
//      }
//    }
//  }
//  
//  private static func createDefaultDiyRunner(context: ModelContext) {
//    let diyExists = (try? context.fetchCount(
//      FetchDescriptor<RunnerModel>(
//        predicate: #Predicate { $0.type == "diy" }
//      )
//    )) ?? 0 > 0
//    
//    if !diyExists {
//      guard let url = Bundle.main.url(forResource: "hello", withExtension: "gif"),
//            let gifData = try? Data(contentsOf: url)
//      else { return }
//      
//      let runner = RunnerModel(
//        id: UUID(),
//        type: "diy",
//        // 稍后设置
//        frame_number: 0,
//        data: gifData
//      )
//      _ = runner.setGIF(data: gifData)
//      context.insert(runner)
//    }
//  }
}
