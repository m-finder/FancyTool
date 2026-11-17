import Accelerate
import CoreGraphics
import Foundation

/// Appends only new rows from overlapping, downward-scrolling viewports.
/// Matching uses a small grayscale copy; the retained image strips keep their
/// original resolution and are composited only when capture finishes.
struct ShotterScrollStitcher {
  enum Update: Equatable {
    case appended
    case unchanged
    case noOverlap
    case limitReached
  }

  private(set) var pixelWidth = 0
  var pixelHeight: Int { max(0, stitchedHeight - topInset - bottomInset) }
  private var stitchedHeight = 0
  private let topInset: Int
  private let bottomInset: Int
  private(set) var frameCount = 0

  private let maximumPixelCount: Int
  private let maximumHeight: Int
  private var previous: Signature?
  private var strips: [CGImage] = []
  private var initialImage: CGImage?
  private var fixedLeft = 0
  private var fixedRight = 0
  private var sideInsertionRow = 0

  init(maximumPixelCount: Int = 96_000_000, maximumHeight: Int = 65_000,
    topInset: Int = 0, bottomInset: Int = 0) {
    self.topInset = max(0, topInset)
    self.bottomInset = max(0, bottomInset)
    self.maximumPixelCount = max(1, maximumPixelCount)
    self.maximumHeight = max(1, maximumHeight)
  }

  mutating func append(_ image: CGImage, maximumDisplacement: Int? = nil) -> Update {
    guard image.width > 0, image.height > topInset, image.height - topInset > bottomInset,
      image.height <= maximumHeight,
      image.width <= maximumPixelCount / image.height
    else { return .limitReached }
    if pixelWidth != 0,
      image.width != pixelWidth || image.height != previous?.height
    {
      return .noOverlap
    }
    guard let signature = Signature(image: image) else { return .noOverlap }

    guard let previous else {
      guard let initial = Self.copyRows(of: image, startingAt: 0, count: image.height) else {
        return .limitReached
      }
      strips = [initial]
      initialImage = initial
      self.previous = signature
      pixelWidth = image.width
      stitchedHeight = image.height
      frameCount = 1
      return .appended
    }

    if previous.isVisuallyUnchanged(from: signature) { return .unchanged }
    guard let match = previous.registration(to: signature)
    else { return .noOverlap }
    let displacement = match.displacement
    guard displacement > 0 else { return .unchanged }
    if let maximumDisplacement, displacement > maximumDisplacement { return .noOverlap }
    guard displacement <= maximumHeight - stitchedHeight,
      pixelWidth <= maximumPixelCount / (stitchedHeight + displacement),
      let strip = Self.copyRows(of: image, startingAt: match.seam, count: image.height - match.seam)
    else {
      return .limitReached
    }
    let retainedHeight = stitchedHeight - image.height + match.seam + displacement
    guard trim(to: retainedHeight) else { return .limitReached }
    strips.append(strip)
    if frameCount == 1 {
      fixedLeft = match.left * pixelWidth / signature.width
      fixedRight = (signature.width - match.right) * pixelWidth / signature.width
      if let initialImage,
        let row = previous.sideInsertionRow(
          left: match.left, right: match.right,
          bodyBottom: match.bodyBottom, image: initialImage)
      {
        sideInsertionRow = row
      } else {
        fixedLeft = 0
        fixedRight = 0
      }
    } else {
      fixedLeft = min(fixedLeft, match.left * pixelWidth / signature.width)
      fixedRight = min(fixedRight, (signature.width - match.right) * pixelWidth / signature.width)
    }
    if fixedLeft == 0 && fixedRight == 0 { initialImage = nil }
    self.previous = signature
    stitchedHeight += displacement
    frameCount += 1
    return .appended
  }

  private mutating func trim(to height: Int) -> Bool {
    var trimmed = strips
    var remaining = stitchedHeight - height
    while let last = trimmed.last, remaining >= last.height {
      remaining -= last.height
      trimmed.removeLast()
    }
    if remaining > 0, let last = trimmed.last {
      guard let cropped = Self.copyRows(of: last, startingAt: 0, count: last.height - remaining)
      else { return false }
      trimmed[trimmed.count - 1] = cropped
    }
    strips = trimmed
    return true
  }

  func makeImage() -> CGImage? {
    render(width: pixelWidth, height: pixelHeight)
  }

  func makePreview(maximumSize: CGSize) -> CGImage? {
    guard pixelWidth > 0, pixelHeight > 0,
      maximumSize.width.isFinite, maximumSize.height.isFinite,
      maximumSize.width >= 1, maximumSize.height >= 1
    else { return nil }
    let scale = min(
      1, maximumSize.width / CGFloat(pixelWidth), maximumSize.height / CGFloat(pixelHeight))
    return render(
      width: max(1, Int((CGFloat(pixelWidth) * scale).rounded(.down))),
      height: max(1, Int((CGFloat(pixelHeight) * scale).rounded(.down))))
  }

  private func render(width: Int, height: Int) -> CGImage? {
    guard pixelWidth > 0, pixelHeight > 0,
      let context = Self.bitmap(width: width, height: height)
    else { return nil }
    let isPreview = width != pixelWidth || height != pixelHeight
    context.interpolationQuality = isPreview ? .medium : .none
    if isPreview { context.setShouldAntialias(false) }
    context.scaleBy(x: CGFloat(width) / CGFloat(pixelWidth), y: CGFloat(height) / CGFloat(pixelHeight))
    context.translateBy(x: 0, y: -CGFloat(bottomInset))
    var top = stitchedHeight
    for strip in strips {
      top -= strip.height
      context.draw(strip, in: CGRect(x: 0, y: top, width: pixelWidth, height: strip.height))
    }
    if let initialImage, stitchedHeight > initialImage.height {
      for (x, bandWidth) in [(0, fixedLeft), (pixelWidth - fixedRight, fixedRight)]
      where bandWidth > 0 {
        let growth = stitchedHeight - initialImage.height
        let sections = [
          (0, sideInsertionRow, 0, sideInsertionRow),
          (sideInsertionRow, 1, sideInsertionRow, growth),
          (
            sideInsertionRow, initialImage.height - sideInsertionRow,
            sideInsertionRow + growth, initialImage.height - sideInsertionRow
          ),
        ]
        for (sourceY, sourceHeight, destinationY, destinationHeight) in sections
        where sourceHeight > 0 && destinationHeight > 0 {
          guard
            let band = initialImage.cropping(
              to: CGRect(x: x, y: sourceY, width: bandWidth, height: sourceHeight))
          else { continue }
          context.draw(
            band,
            in: CGRect(
              x: x, y: stitchedHeight - destinationY - destinationHeight,
              width: bandWidth, height: destinationHeight))
        }
      }
    }
    return context.makeImage()
  }

  private static func bitmap(width: Int, height: Int) -> CGContext? {
    CGContext(
      data: nil, width: width, height: height, bitsPerComponent: 8,
      bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
  }

  private static func copyRows(of image: CGImage, startingAt row: Int, count: Int) -> CGImage? {
    guard let crop = image.cropping(to: CGRect(x: 0, y: row, width: image.width, height: count)),
      let context = bitmap(width: image.width, height: count)
    else { return nil }
    // CGImage.cropping alone can retain the entire source frame. Copy each
    // strip into independent storage so tiny scrolls do not retain full frames.
    context.interpolationQuality = .none
    context.draw(crop, in: CGRect(x: 0, y: 0, width: image.width, height: count))
    return context.makeImage()
  }

  private struct Signature {
    let width: Int
    let height: Int
    let sourceWidth: Int
    let pixels: [UInt8]

    init?(image: CGImage) {
      let width = min(192, image.width)
      let height = image.height
      var bytes = [UInt8](repeating: 0, count: width * height)
      let rendered = Self.samplePixels(of: image, into: &bytes) || bytes.withUnsafeMutableBytes { buffer -> Bool in
        guard let context = CGContext(
          data: buffer.baseAddress, width: width, height: height,
          bitsPerComponent: 8, bytesPerRow: width,
          space: CGColorSpaceCreateDeviceGray(), bitmapInfo: 0)
        else { return false }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return true
      }
      guard rendered else { return nil }
      self.width = width
      self.height = height
      sourceWidth = image.width
      pixels = bytes
    }

    private static func samplePixels(of image: CGImage, into output: inout [UInt8]) -> Bool {
      guard image.width >= 1500, image.bitsPerComponent == 8, image.bitsPerPixel == 32,
        let provider = image.dataProvider, let data = provider.data,
        image.bytesPerRow >= image.width * 4,
        image.bytesPerRow <= Int.max / image.height,
        CFDataGetLength(data) >= image.bytesPerRow * image.height
      else { return false }
      defer { withExtendedLifetime(data) {} }
      let order = image.bitmapInfo.intersection(.byteOrderMask)
      let red: Int
      let green: Int
      let blue: Int
      switch (order, image.alphaInfo) {
      case (.byteOrder32Little, .premultipliedFirst), (.byteOrder32Little, .first),
           (.byteOrder32Little, .noneSkipFirst):
        (red, green, blue) = (2, 1, 0)
      case (.byteOrderDefault, .premultipliedLast), (.byteOrderDefault, .last),
           (.byteOrderDefault, .noneSkipLast), (.byteOrder32Big, .premultipliedLast),
           (.byteOrder32Big, .last), (.byteOrder32Big, .noneSkipLast):
        (red, green, blue) = (0, 1, 2)
      default:
        return false
      }
      let sampledWidth = output.count / image.height
      var source = vImage_Buffer(data: UnsafeMutableRawPointer(mutating: CFDataGetBytePtr(data)!),
        height: vImagePixelCount(image.height), width: vImagePixelCount(image.width),
        rowBytes: image.bytesPerRow)
      var scaledBytes = [UInt8](repeating: 0, count: sampledWidth * image.height * 4)
      var matrix = [Int16](repeating: 0, count: 4)
      matrix[red] = 54
      matrix[green] = 183
      matrix[blue] = 19
      return scaledBytes.withUnsafeMutableBytes { scaledStorage in
        var scaled = vImage_Buffer(data: scaledStorage.baseAddress!,
          height: source.height, width: vImagePixelCount(sampledWidth), rowBytes: sampledWidth * 4)
        guard vImageScale_ARGB8888(&source, &scaled, nil, vImage_Flags(kvImageHighQualityResampling)) == kvImageNoError
        else { return false }
        return output.withUnsafeMutableBytes { outputStorage in
          var gray = vImage_Buffer(data: outputStorage.baseAddress!, height: source.height,
            width: vImagePixelCount(sampledWidth), rowBytes: sampledWidth)
          return vImageMatrixMultiply_ARGB8888ToPlanar8(&scaled, &gray, &matrix, 256, nil, 0,
            vImage_Flags(kvImageNoFlags)) == kvImageNoError
        }
      }
    }

    func isVisuallyUnchanged(from other: Signature) -> Bool {
      pixels == other.pixels
    }

    struct Match {
      let displacement: Int
      let seam: Int
      let left: Int
      let right: Int
      let bodyBottom: Int
    }

    func registration(to other: Signature) -> Match? {
      let columns = movingColumns(to: other)
      guard columns.count >= 4,
        let rows = movingRows(to: other, columns: columns), rows.count > 24 else { return nil }
      guard rows.overlaps((height / 4)..<(height * 3 / 4)) else {
        return Match(displacement: 0, seam: 0, left: 0, right: width, bodyBottom: height)
      }
      let sampled = stride(from: 0, to: columns.count, by: max(1, columns.count / 32))
        .map { columns[$0] }
      let count = rows.count
      let correlationCount = count * 2 - 1
      let firstGradient = horizontalGradient()
      let secondGradient = other.horizontalGradient()
      var correlations = [Float](repeating: 0, count: correlationCount)
      var firstEnergy = [Float](repeating: 0, count: count + 1)
      var secondEnergy = firstEnergy
      var firstVariation = firstEnergy
      var secondVariation = firstEnergy
      for x in sampled {
        var first = [Float](repeating: 0, count: count * 3 - 2)
        var second = [Float](repeating: 0, count: count)
        first.withUnsafeMutableBufferPointer { a in
          second.withUnsafeMutableBufferPointer { b in
            let p = a.baseAddress! + count - 1
            let q = b.baseAddress!
            if x >= 2 {
              var one: Float = 1
              firstGradient.withUnsafeBufferPointer {
                vDSP_vsmul($0.baseAddress! + rows.lowerBound * width + x - 2, width,
                  &one, p, 1, vDSP_Length(count))
              }
              secondGradient.withUnsafeBufferPointer {
                vDSP_vsmul($0.baseAddress! + rows.lowerBound * width + x - 2, width,
                  &one, q, 1, vDSP_Length(count))
              }
            } else {
              for y in 0..<count {
                let row = (y + rows.lowerBound) * width
                p[y] = Float(Int(pixels[row + x]) - Int(pixels[row]))
                q[y] = Float(Int(other.pixels[row + x]) - Int(other.pixels[row]))
              }
            }
            firstEnergy.withUnsafeMutableBufferPointer {
              vDSP_vma(p, 1, p, 1, $0.baseAddress! + 1, 1, $0.baseAddress! + 1, 1, vDSP_Length(count))
            }
            secondEnergy.withUnsafeMutableBufferPointer {
              vDSP_vma(q, 1, q, 1, $0.baseAddress! + 1, 1, $0.baseAddress! + 1, 1, vDSP_Length(count))
            }
            var variation = [Float](repeating: 0, count: count - 1)
            vDSP_vsub(p, 1, p + 1, 1, &variation, 1, vDSP_Length(count - 1))
            firstVariation.withUnsafeMutableBufferPointer {
              vDSP_vma(variation, 1, variation, 1, $0.baseAddress! + 2, 1,
                $0.baseAddress! + 2, 1, vDSP_Length(count - 1))
            }
            vDSP_vsub(q, 1, q + 1, 1, &variation, 1, vDSP_Length(count - 1))
            secondVariation.withUnsafeMutableBufferPointer {
              vDSP_vma(variation, 1, variation, 1, $0.baseAddress! + 2, 1,
                $0.baseAddress! + 2, 1, vDSP_Length(count - 1))
            }
          }
        }
        var channel = [Float](repeating: 0, count: correlationCount)
        vDSP_conv(first, 1, second, 1, &channel, 1,
          vDSP_Length(correlationCount), vDSP_Length(count))
        vDSP_vadd(correlations, 1, channel, 1, &correlations, 1, vDSP_Length(correlationCount))
      }
      var firstEdges = [Int](repeating: 0, count: count + 1)
      var secondEdges = firstEdges
      for y in 1...count {
        firstEdges[y] = firstEdges[y - 1] + (firstVariation[y] > Float(sampled.count * 2) ? 1 : 0)
        secondEdges[y] = secondEdges[y - 1] + (secondVariation[y] > Float(sampled.count * 2) ? 1 : 0)
        firstEnergy[y] += firstEnergy[y - 1]
        secondEnergy[y] += secondEnergy[y - 1]
      }
      var candidates: [(shift: Int, cost: Float)] = []
      let maximumShift = min(height - 24, count - 8)
      for shift in (-maximumShift)...maximumShift {
        let firstStart = max(0, shift)
        let secondStart = max(0, -shift)
        let overlap = count - abs(shift)
        guard firstEdges[firstStart + overlap] - firstEdges[firstStart + 1] > 0,
          secondEdges[secondStart + overlap] - secondEdges[secondStart + 1] > 0 else { continue }
        let energy = firstEnergy[firstStart + overlap] - firstEnergy[firstStart]
          + secondEnergy[secondStart + overlap] - secondEnergy[secondStart]
        guard energy > Float(overlap * sampled.count * 2) else { continue }
        let cost = max(0, (energy - 2 * correlations[shift + count - 1]) / energy)
        candidates.append((shift, cost))
      }
      candidates.sort {
        $0.cost == $1.cost ? abs($0.shift) < abs($1.shift) : $0.cost < $1.cost
      }
      if let best = candidates.first, best.shift > 0, best.cost < 0.15 {
        let alternate = candidates.first(where: { $0.shift > 0 && abs($0.shift - best.shift) > 3 })
        if alternate == nil || alternate!.cost > max(best.cost * 1.7, 0.0001) {
          return makeMatch(to: other, shift: best.shift, columns: columns)
        }
      }
      var shifts = Array(candidates.prefix(6)).filter { $0.cost < 0.8 }
      let minimumOverlap = max(24, count / 4)
      shifts = shifts.filter { count - abs($0.shift) >= minimumOverlap }
      if !shifts.contains(where: { $0.shift == 0 }) { shifts.append((0, 0)) }
      guard !shifts.isEmpty else { return nil }
      let safeColumns = sampled.filter { $0 >= 5 && $0 < width - 6 }
      guard safeColumns.count >= 4 else { return nil }
      var refined = refine(
        candidates: shifts, first: firstGradient, second: secondGradient,
        rows: rows, columns: safeColumns)
      refined.sort { $0.cost < $1.cost }
      if let best = refined.first, best.shift > 0, best.cost < 0.15 {
        let alternate = refined.first(where: { abs($0.shift - best.shift) > 3 })
        if alternate == nil || alternate!.cost > max(best.cost * 1.7, 0.0001) {
          return makeMatch(to: other, shift: best.shift, columns: columns)
        }
      }
      guard let shift = localRegistration(first: firstGradient, second: secondGradient)
      else { return nil }
      return makeMatch(to: other, shift: shift, columns: columns)
    }

    private func horizontalGradient() -> [Float] {
      var values = [Float](repeating: 0, count: pixels.count)
      vDSP_vfltu8(pixels, 1, &values, 1, vDSP_Length(pixels.count))
      var gradient = values
      values.withUnsafeBufferPointer { buffer in
        vDSP_vsub(buffer.baseAddress!, 1, buffer.baseAddress! + 2, 1,
          &gradient, 1, vDSP_Length(pixels.count - 2))
      }
      return gradient
    }

    private func refine(
      candidates shifts: [(shift: Int, cost: Float)], first: [Float], second: [Float],
      rows: Range<Int>, columns: [Int]
    ) -> [(shift: Int, cost: Float)] {
      var refined: [(shift: Int, cost: Float)] = []
      for candidate in shifts {
        let overlap = rows.count - abs(candidate.shift)
        guard overlap >= 24 else { continue }
        var bestCost: Float = 1
        for dx in -3...2 {
          var aa: Float = 0, bb: Float = 0, cc: Float = 0
          var ab: Float = 0, ac: Float = 0, bc: Float = 0
          first.withUnsafeBufferPointer { a in
            second.withUnsafeBufferPointer { b in
              for x in columns {
                let p = a.baseAddress! + (rows.lowerBound + max(0, candidate.shift)) * width + x - 2
                let q = b.baseAddress! + (rows.lowerBound + max(0, -candidate.shift)) * width + x - 2 + dx
                let r = q + 1
                var value: Float = 0
                vDSP_dotpr(p, width, p, width, &value, vDSP_Length(overlap)); aa += value
                vDSP_dotpr(q, width, q, width, &value, vDSP_Length(overlap)); bb += value
                vDSP_dotpr(r, width, r, width, &value, vDSP_Length(overlap)); cc += value
                vDSP_dotpr(p, width, q, width, &value, vDSP_Length(overlap)); ab += value
                vDSP_dotpr(p, width, r, width, &value, vDSP_Length(overlap)); ac += value
                vDSP_dotpr(q, width, r, width, &value, vDSP_Length(overlap)); bc += value
              }
            }
          }
          let delta = max(0, cc + bb - 2 * bc)
          let fraction = delta > 0 ? max(0, min(1, (ac - ab + bb - bc) / delta)) : 0
          let energy = aa + bb + 2 * fraction * (bc - bb) + fraction * fraction * delta
          guard energy > Float(overlap * columns.count * 2) else { continue }
          guard abs((Float(dx) + fraction) * Float(sourceWidth) / Float(width)) <= 8 else { continue }
          let cost = max(0, (energy - 2 * (ab + fraction * (ac - ab))) / energy)
          if cost < bestCost { bestCost = cost }
        }
        refined.append((candidate.shift, bestCost))
      }
      return refined
    }

    private func localRegistration(first: [Float], second: [Float]) -> Int? {
      let patchHeight = min(32, max(16, height / 24))
      guard height >= patchHeight * 2 else { return nil }
      let patchStride = max(8, patchHeight / 2)
      let inset = max(3, width / 32)
      let interiorColumns = (inset..<(width - inset)).filter { x in
        var changed = 0
        for y in (height / 4)..<(height * 3 / 4) {
          if abs(first[y * width + x] - second[y * width + x]) > 6 { changed += 1 }
        }
        return changed >= 3
      }
      guard interiorColumns.count >= 8 else { return nil }
      let columns = stride(from: 0, to: interiorColumns.count, by: max(1, interiorColumns.count / 32))
        .map { interiorColumns[$0] }
      var votes: [(shift: Int, row: Int)] = []
      var firstEnergy = [Float](repeating: 0, count: height + 1)
      var channels: [[Float]] = []
      first.withUnsafeBufferPointer { source in
        firstEnergy.withUnsafeMutableBufferPointer { energy in
          for x in columns {
            var channel = [Float](repeating: 0, count: height + patchHeight * 2 - 2)
            let p = source.baseAddress! + x
            var one: Float = 1
            channel.withUnsafeMutableBufferPointer {
              vDSP_vsmul(p, width, &one, $0.baseAddress! + patchHeight - 1, 1, vDSP_Length(height))
            }
            vDSP_vma(p, width, p, width, energy.baseAddress! + 1, 1,
              energy.baseAddress! + 1, 1, vDSP_Length(height))
            channels.append(channel)
          }
        }
      }
      for y in 1...height { firstEnergy[y] += firstEnergy[y - 1] }
      let originCount = height - patchHeight + 1
      for (row, start) in stride(from: 0, through: height - patchHeight, by: patchStride).enumerated() {
        var secondEnergy: Float = 0
        var correlation = [Float](repeating: 0, count: height + patchHeight - 1)
        var channel = correlation
        var patch = [Float](repeating: 0, count: patchHeight)
        second.withUnsafeBufferPointer { source in
          for (index, x) in columns.enumerated() {
            var one: Float = 1
            vDSP_vsmul(source.baseAddress! + start * width + x, width,
              &one, &patch, 1, vDSP_Length(patchHeight))
            var energy: Float = 0
            vDSP_svesq(patch, 1, &energy, vDSP_Length(patchHeight))
            secondEnergy += energy
            vDSP_conv(channels[index], 1, patch, 1, &channel, 1,
              vDSP_Length(correlation.count), vDSP_Length(patchHeight))
            vDSP_vadd(correlation, 1, channel, 1, &correlation, 1, vDSP_Length(correlation.count))
          }
        }
        guard secondEnergy > Float(patchHeight * columns.count * 2) else { continue }
        var energies = [Float](repeating: 0, count: originCount)
        firstEnergy.withUnsafeBufferPointer {
          vDSP_vsub($0.baseAddress!, 1, $0.baseAddress! + patchHeight, 1,
            &energies, 1, vDSP_Length(originCount))
        }
        vDSP_vsadd(energies, 1, &secondEnergy, &energies, 1, vDSP_Length(originCount))
        var costs = [Float](repeating: 0, count: originCount)
        var negativeTwo: Float = -2
        correlation.withUnsafeBufferPointer {
          vDSP_vsma($0.baseAddress! + patchHeight - 1, 1, &negativeTwo,
            energies, 1, &costs, 1, vDSP_Length(originCount))
        }
        vDSP_vdiv(energies, 1, costs, 1, &costs, 1, vDSP_Length(originCount))
        var candidates: [(shift: Int, cost: Float)] = []
        for origin in 0..<originCount {
          let cost = max(0, costs[origin])
          if cost < 0.15 { candidates.append((origin - start, cost)) }
        }
        candidates.sort { $0.cost < $1.cost }
        var peaks: [Int] = []
        for candidate in candidates where candidate.cost < 0.15 {
          guard !peaks.contains(where: { abs($0 - candidate.shift) <= 3 }) else { continue }
          votes.append((candidate.shift, row))
          peaks.append(candidate.shift)
          if peaks.count == 4 { break }
        }
      }
      var comparisons: [Int: RowComparison] = [:]
      let verified = votes.compactMap { vote -> (shift: Int, row: Int, cost: Float)? in
        let comparison: RowComparison
        if let cached = comparisons[vote.shift] {
          comparison = cached
        } else {
          comparison = compareRows(first: first, second: second, shift: vote.shift, columns: interiorColumns)
          comparisons[vote.shift] = comparison
        }
        let start = vote.row * patchStride - max(0, -vote.shift)
        var error: Float = 0, energy: Float = 0
        comparison.errors.withUnsafeBufferPointer {
          vDSP_sve($0.baseAddress! + start, 1, &error, vDSP_Length(patchHeight))
        }
        comparison.energies.withUnsafeBufferPointer {
          vDSP_sve($0.baseAddress! + start, 1, &energy, vDSP_Length(patchHeight))
        }
        guard energy > 0, error / energy < 0.03 else { return nil }
        return (vote.shift, vote.row, error / energy)
      }
      let shifts = Set(verified.filter { $0.shift != 0 }.map { $0.shift })
      let groups = shifts.compactMap { shift -> (shift: Int, cost: Float, count: Int)? in
        let matches = verified.filter { abs($0.shift - shift) <= 1 }
        guard matches.count >= 2, Set(matches.map { $0.row }).count >= 2 else { return nil }
        let costs = matches.map { $0.cost }.sorted()
        return (shift, (costs[0] + costs[1]) / 2, matches.count)
      }.sorted { $0.cost == $1.cost ? $0.count > $1.count : $0.cost < $1.cost }
      let supported = groups.filter { candidate in
        let shift = candidate.shift
        let overlap = height - abs(shift)
        let minimumRun = max(24, overlap - height / 4)
        guard let comparison = comparisons[shift] else { return false }
        var start = 0, bestRun = 0, edgeRows = 0, bestEdges = 0
        for row in 0..<overlap {
          let error = comparison.errors[row]
          let energy = comparison.energies[row]
          if error > max(4 * Float(interiorColumns.count), energy * 0.08) {
            start = row + 1
            edgeRows = 0
          } else {
            if energy > Float(interiorColumns.count * 4) { edgeRows += 1 }
            if row - start + 1 > bestRun {
              bestRun = row - start + 1
              bestEdges = edgeRows
            }
          }
        }
        return bestRun >= minimumRun && bestEdges >= 6
      }
      guard let best = supported.first, best.shift > 0 else { return nil }
      if let alternate = supported.first(where: { abs($0.shift - best.shift) > 1 }),
        alternate.cost <= max(best.cost * 1.7, 0.0001), alternate.count >= best.count { return nil }
      return best.shift
    }

    private struct RowComparison {
      let errors: [Float]
      let energies: [Float]
    }

    private func compareRows(first: [Float], second: [Float], shift: Int, columns: [Int]) -> RowComparison {
      let overlap = height - abs(shift)
      let count = vDSP_Length(overlap)
      var errors = [Float](repeating: 0, count: overlap)
      var energies = errors
      var differences = errors
      first.withUnsafeBufferPointer { a in
        second.withUnsafeBufferPointer { b in
          errors.withUnsafeMutableBufferPointer { error in
            energies.withUnsafeMutableBufferPointer { energy in
              differences.withUnsafeMutableBufferPointer { difference in
                for x in columns {
                  let p = a.baseAddress! + max(0, shift) * width + x
                  let q = b.baseAddress! + max(0, -shift) * width + x
                  vDSP_vsub(p, width, q, width, difference.baseAddress!, 1, count)
                  vDSP_vma(difference.baseAddress!, 1, difference.baseAddress!, 1,
                    error.baseAddress!, 1, error.baseAddress!, 1, count)
                  vDSP_vma(p, width, p, width, energy.baseAddress!, 1, energy.baseAddress!, 1, count)
                  vDSP_vma(q, width, q, width, energy.baseAddress!, 1, energy.baseAddress!, 1, count)
                }
              }
            }
          }
        }
      }
      return RowComparison(errors: errors, energies: energies)
    }

    private func movingColumns(to other: Signature) -> [Int] {
      let inset = 1
      return (inset..<(width - inset)).filter { x in
        var changed = 0
        for index in 0..<min(height, 160) {
          let y = index * height / min(height, 160)
          if abs(Int(pixels[y * width + x]) - Int(other.pixels[y * width + x])) > 6 {
            changed += 1
          }
        }
        return changed >= 3
      }
    }

    private func movingRows(to other: Signature, columns: [Int]) -> Range<Int>? {
      let sampled = stride(from: 0, to: columns.count, by: max(1, columns.count / 24))
        .map { columns[$0] }
      var first = height
      var last = 0
      for y in 0..<height {
        var changed = 0
        for x in sampled where abs(Int(pixels[y * width + x]) - Int(other.pixels[y * width + x])) > 6 {
          changed += 1
          if changed >= 2 { break }
        }
        if changed >= 2 {
          first = min(first, y)
          last = y
        }
      }
      guard last - first >= 24 else { return nil }
      return max(0, first - 1)..<min(height, last + 2)
    }

    private func makeMatch(to other: Signature, shift: Int, columns: [Int]) -> Match? {
      pixels.withUnsafeBufferPointer { firstBuffer in
        other.pixels.withUnsafeBufferPointer { secondBuffer in
          let firstPixels = firstBuffer.baseAddress!
          let secondPixels = secondBuffer.baseAddress!
          let sparseColumns = stride(from: 0, to: columns.count, by: max(1, columns.count / 24))
            .map { columns[$0] }
          var firstMovingRow = height
          var lastMovingRow = 0
          for y in 0..<height {
            var changed = 0
            for x in sparseColumns {
              if abs(Int(firstPixels[y * width + x]) - Int(secondPixels[y * width + x])) > 6 {
                changed += 1
              }
            }
            if changed >= 2 {
              firstMovingRow = min(firstMovingRow, y)
              lastMovingRow = y
            }
          }
          let lowerSeam = firstMovingRow
          let upperSeam = min(height - shift, lastMovingRow - shift)
          guard upperSeam >= lowerSeam else { return nil }
          var left = columns.first! > width / 8 ? max(0, columns.first! - 2) : 0
          var right = columns.last! < width * 7 / 8 ? min(width, columns.last! + 3) : width
          for x in 0..<left {
            var changes = 0
            for y in 0..<height {
              if abs(Int(firstPixels[y * width + x]) - Int(secondPixels[y * width + x])) > 2 {
                changes += 1
              }
            }
            if changes > 0 {
              left = x
              break
            }
          }
          for x in (right..<width).reversed() {
            var changes = 0
            for y in 0..<height {
              if abs(Int(firstPixels[y * width + x]) - Int(secondPixels[y * width + x])) > 2 {
                changes += 1
              }
            }
            if changes > 0 {
              right = x + 1
              break
            }
          }
          return Match(
            displacement: shift, seam: lowerSeam + (upperSeam - lowerSeam) * 3 / 4,
            left: left, right: right, bodyBottom: lastMovingRow)
        }
      }
    }

    func sideInsertionRow(left: Int, right: Int, bodyBottom: Int, image: CGImage) -> Int? {
      let lastRow = max(1, min(height - 3, bodyBottom - 2))
      let firstRow = lastRow * 2 / 3
      let leftEdge = left * image.width / width
      let rightEdge = right * image.width / width
      let columns = Array(0..<leftEdge) + Array(rightEdge..<image.width)
      guard !columns.isEmpty else { return nil }
      var bytes = [UInt8](repeating: 0, count: image.width * height)
      let rendered = bytes.withUnsafeMutableBytes { buffer -> Bool in
        guard
          let context = CGContext(
            data: buffer.baseAddress, width: image.width, height: height,
            bitsPerComponent: 8, bytesPerRow: image.width,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: 0)
        else { return false }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: height))
        return true
      }
      guard rendered else { return nil }
      var best = (row: lastRow, cost: 256)
      bytes.withUnsafeBufferPointer { buffer in
        let source = buffer.baseAddress!
        for y in firstRow...lastRow {
          var low = 255
          var high = 0
          for row in (y - 1)...(y + 1) {
            for x in columns {
              let value = Int(source[row * image.width + x])
              low = min(low, value)
              high = max(high, value)
            }
          }
          let cost = high - low
          if cost <= best.cost + 1 { best = (y, cost) }
        }
      }
      return best.cost < 48 ? best.row : nil
    }

  }
}
