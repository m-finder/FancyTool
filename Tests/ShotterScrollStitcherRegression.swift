import CoreGraphics
import CoreText
import Foundation
import ImageIO

@main
struct ShotterScrollStitcherRegression {
  static func bitmap(width: Int, height: Int) -> CGContext {
    CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
      bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  }

  static func codeImage(width: Int, scale: Int, lineNumbers: Bool = false) throws -> CGImage {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let source = try String(contentsOf: root.appendingPathComponent(
      "Tests/Fixtures/Scrolling/code-document.txt"), encoding: .utf8)
    let lines = source.components(separatedBy: "\n")
    let context = bitmap(width: width + 20 * scale, height: (lines.count * 22 + 200) * scale)
    context.setFillColor(CGColor(gray: 0.12, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: context.width, height: context.height))
    let attributes: [NSAttributedString.Key: Any] = [
      .init(kCTFontAttributeName as String): CTFontCreateWithName("Menlo" as CFString, CGFloat(13 * scale), nil),
      .init(kCTForegroundColorAttributeName as String): CGColor(gray: 0.85, alpha: 1),
    ]
    for (index, line) in lines.enumerated() {
      let baseline = context.height - (index * 22 + 18) * scale
      if lineNumbers {
        context.textPosition = CGPoint(x: 8 * scale, y: baseline)
        CTLineDraw(CTLineCreateWithAttributedString(NSAttributedString(string: String(index + 1), attributes: attributes)), context)
      }
      context.textPosition = CGPoint(x: (lineNumbers ? 60 : 8) * scale, y: baseline)
      CTLineDraw(CTLineCreateWithAttributedString(NSAttributedString(string: line, attributes: attributes)), context)
    }
    return context.makeImage()!
  }

  static func pixels(_ image: CGImage) -> Data {
    let context = bitmap(width: image.width, height: image.height)
    context.interpolationQuality = .none
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    return Data(bytes: context.data!, count: image.width * image.height * 4)
  }

  static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
  }

  static func changingHeader(scale: Int, steps: [Int] = [30, 70, 110], frames: Int = 100) throws {
    let width = 1800 * scale
    let height = 400 * scale
    let header = 55 * scale
    let footer = 25 * scale
    let sidebar = 240 * scale
    let document = try codeImage(width: width - sidebar, scale: scale, lineNumbers: true)
    var stitcher = ShotterScrollStitcher()
    var offset = 0
    for index in 0...frames {
      if index > 0 { offset += steps[index % steps.count] * scale }
      let context = bitmap(width: width, height: height)
      context.setFillColor(CGColor(gray: 0.16, alpha: 1))
      context.fill(CGRect(x: 0, y: 0, width: width, height: height))
      let body = document.cropping(to: CGRect(x: 0, y: offset,
        width: width - sidebar, height: height - header - footer))!
      context.draw(body, in: CGRect(x: sidebar, y: footer, width: body.width, height: body.height))
      let attributes: [NSAttributedString.Key: Any] = [
        .init(kCTFontAttributeName as String): CTFontCreateWithName("Menlo" as CFString, CGFloat(18 * scale), nil),
        .init(kCTForegroundColorAttributeName as String): CGColor(gray: 1, alpha: 1),
      ]
      context.textPosition = CGPoint(x: 20 * scale, y: height - 35 * scale)
      let labels = ["Indexing project files…", "Downloading documentation…", "Building module caches…", "Analyzing source code…"]
      CTLineDraw(CTLineCreateWithAttributedString(NSAttributedString(
        string: "\(labels[(index / 3) % labels.count])    \(index * 13)%    FancyTool", attributes: attributes)), context)
      let sidebarAttributes: [NSAttributedString.Key: Any] = [
        .init(kCTFontAttributeName as String): CTFontCreateWithName("Menlo" as CFString, CGFloat(12 * scale), nil),
        .init(kCTForegroundColorAttributeName as String): CGColor(gray: 0.7, alpha: 1),
      ]
      for (row, label) in ["Project", "  FancyTool", "    Modules", "      Shotter", "    Resources"].enumerated() {
        context.textPosition = CGPoint(x: 10 * scale, y: height - (85 + row * 26) * scale)
        CTLineDraw(CTLineCreateWithAttributedString(NSAttributedString(string: label, attributes: sidebarAttributes)), context)
      }
      _ = stitcher.append(context.makeImage()!)
      require(stitcher.pixelHeight == height + offset,
        "Changing fixed header stopped capture at frame \(index), steps \(steps), @\(scale)x")
    }
    let result = stitcher.makeImage()!
    let bodyHeight = height - header - footer + offset
    for row in stride(from: 0, to: bodyHeight, by: 128) {
      let count = min(128, bodyHeight - row)
      let actual = result.cropping(to: CGRect(x: sidebar + 16 * scale, y: header + row,
        width: width - sidebar - 32 * scale, height: count))!
      let expected = document.cropping(to: CGRect(x: 16 * scale, y: row,
        width: actual.width, height: count))!
      require(pixels(actual) == pixels(expected),
        "Missing or repeated body rows at \(row), steps \(steps), @\(scale)x")
    }
    print("PASS changing fixed header @\(scale)x: \(frames) frames, steps \(steps), exact body pixels")
  }

  static func main() throws {
    let fixtureDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .appendingPathComponent("Fixtures/Scrolling")
    for (name, displacement) in [("web-horizontal", 80), ("web-fixed-sidebar", 80),
      ("web-large-scroll", 320), ("web-repeated-code", 560), ("web-header-update", 0)] {
      var stitcher = ShotterScrollStitcher()
      for (index, suffix) in ["before", "after"].enumerated() {
        let url = fixtureDirectory.appendingPathComponent("\(name)-\(suffix).png")
        let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
        let expected: ShotterScrollStitcher.Update = index == 1 && displacement == 0 ? .unchanged : .appended
        require(stitcher.append(image) == expected, "Recorded WebKit frame rejected: \(name)")
        require(stitcher.pixelHeight == image.height + index * displacement, "Recorded WebKit displacement: \(name)")
      }
      print("PASS recorded WebKit frames: \(name)")
    }
    for scale in [1, 2] {
      try changingHeader(scale: scale)
      for step in [200, 220, 260, 280] {
        try changingHeader(scale: scale, steps: [step], frames: 20)
      }
      for width in [400, 1000] {
        let document = try codeImage(width: width * scale, scale: scale)
        for height in [160, 500] {
          let pixelWidth = width * scale
          let pixelHeight = height * scale
          func frame(x: Int, y: Int) -> CGImage {
            document.cropping(to: CGRect(x: x, y: y, width: pixelWidth, height: pixelHeight))!
          }
          var stitcher = ShotterScrollStitcher()
          let initial = frame(x: 0, y: 0)
          require(stitcher.append(initial) == .appended, "Initial frame")
          var offset = 0
          var last = initial
          for index in 1...100 {
            offset += [8, 18, 40][index % 3] * scale
            last = frame(x: min(index, 4) * scale, y: offset)
            _ = stitcher.append(last)
            require(stitcher.pixelHeight == pixelHeight + offset,
              "Stopped or wrong displacement: \(width)x\(height) @\(scale)x, frame \(index)")
          }
          let result = stitcher.makeImage()!
          let tailHeight = 40 * scale
          let tail = result.cropping(to: CGRect(x: 0, y: result.height - tailHeight,
            width: pixelWidth, height: tailHeight))!
          let expectedTail = last.cropping(to: CGRect(x: 0, y: pixelHeight - tailHeight,
            width: pixelWidth, height: tailHeight))!
          require(pixels(tail) == pixels(expectedTail), "Final captured rows must be retained")
          require(stitcher.append(last) == .unchanged, "Identical frame")
          require(stitcher.append(frame(x: 4 * scale, y: offset - 40 * scale)) == .noOverlap,
            "Reverse movement must not add rows")
          require(stitcher.pixelHeight == pixelHeight + offset, "Rejected frame changed output")
          var batch = ShotterScrollStitcher()
          _ = batch.append(initial)
          let jump = pixelHeight * 2 / 3
          require(batch.append(frame(x: 0, y: jump), maximumDisplacement: pixelHeight / 3) == .noOverlap,
            "A distant speculative frame must retain intermediate frames")
          require(batch.pixelHeight == pixelHeight, "Rejected speculative frame changed the anchor")
          _ = batch.append(frame(x: 0, y: 18 * scale))
          require(batch.pixelHeight == pixelHeight + 18 * scale, "Intermediate frame after rejected batch")
          var horizontal = ShotterScrollStitcher()
          _ = horizontal.append(frame(x: 0, y: 100 * scale))
          for x in 1...4 {
            _ = horizontal.append(frame(x: x * scale, y: 100 * scale))
            require(horizontal.pixelHeight == pixelHeight, "Horizontal-only movement added rows")
          }
          print("PASS code \(width)x\(height) @\(scale)x: 100 diagonal frames, export, reverse, horizontal-only")
        }
        for offset in [3900, 5100] {
          var unrelated = ShotterScrollStitcher()
          for (index, y) in [offset, offset + 580].enumerated() {
            let image = document.cropping(to: CGRect(x: 0, y: y * scale,
              width: width * scale, height: 500 * scale))!
            let update = unrelated.append(image)
            require(update == (index == 0 ? .appended : .noOverlap),
              "Repeated code outside the overlap must not be joined")
            require(unrelated.pixelHeight == 500 * scale, "Unrelated code changed the output")
          }
        }
      }
    }
  }
}
