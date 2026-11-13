import CoreGraphics
import Foundation
import ImageIO

/// Original pixel-art frames share one canvas and scale. No body parts are
/// stretched or interpolated when the companion changes activities.
enum RunnerCompanionArt {
  static let size = CGSize(width: 26, height: 22)

  enum Sprite: Int, CaseIterable {
    case blink0 = 0, blink1, blink2, blink3, blink4, blink5
    case turn0 = 8, turn1, turn2, turn3, turn4, turn5, turn6
    case run0 = 16, run1, run2, run3, run4, run5
    case look0 = 24, look1, look2, look3, look4, look5, look6, look7, look8, look9
    case drowsy = 36, lyingDown, asleep
  }

  private static let blink: [Sprite] = [.blink0, .blink1, .blink2, .blink3, .blink4, .blink5]
  private static let turn: [Sprite] = [.turn0, .turn1, .turn2, .turn3, .turn4, .turn5, .turn6]
  private static let run: [Sprite] = [.run0, .run1, .run2, .run3, .run4, .run5]
  private static let look: [Sprite] = [.look0, .look1, .look2, .look3, .look4, .look5, .look6, .look7, .look8, .look9]
  private static let settling: [Sprite] = [.blink5, .drowsy, .lyingDown, .asleep]
  private static let idle: [Sprite] = [.blink5, .blink4, .blink3, .blink2, .blink1, .blink0, .blink1, .blink2, .blink3, .blink4]
  private static let stretching = [.blink5] + turn + Array(repeating: .turn6, count: 3) + turn.dropLast().reversed() + [.blink5]
  private static let charging: [Sprite] = {
    let glance = Array(look.prefix(6))
    return [.blink5] + glance + Array(repeating: .look5, count: 10) + glance.dropLast().reversed() + [.blink5]
  }()
  private static let happy = turn + [.blink5]

  // NSCache synchronizes access and can discard frames under memory pressure.
  private final class FrameCache: @unchecked Sendable {
    let images = NSCache<NSString, CGImage>()
    init() {
      images.countLimit = 96
      images.totalCostLimit = 2 * 1024 * 1024
    }
  }
  private static let frameCache = FrameCache()

  private static let source: CGImage? = {
    guard let url = Bundle.main.url(forResource: "RunnerCompanionDog", withExtension: "png"),
          let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
          image.width == 320, image.height == 880 else { return nil }
    return image
  }()

  static func sequence(for state: RunnerCompanionState) -> [Sprite] {
    switch state {
    case .idle:
      // Keep the source's little tail wag and blink moving, including the seam.
      return idle
    case .walking, .busy:
      return run
    case .stretching:
      return stretching
    case .charging:
      return charging
    case .sleeping:
      // The later source frames have crossed-out eyes. Use the calm closed-eye
      // sleeping frame, without inventing a breathing deformation.
      return [.asleep]
    case .happy:
      return happy
    }
  }

  static func sprite(state: RunnerCompanionState, elapsed: TimeInterval) -> Sprite {
    let sequence = sequence(for: state)
    let elapsed = elapsed.isFinite ? max(0, elapsed) : 0
    let time = state.loops ? elapsed.truncatingRemainder(dividingBy: state.cycleDuration) : min(elapsed, state.cycleDuration)
    return sequence[min(sequence.count - 1, Int(time / state.frameDuration))]
  }

  static func transitionSprites(from source: Sprite, to state: RunnerCompanionState) -> [Sprite] {
    // Clicks start the turn on this event, without waiting for an entry gesture.
    if state == .happy { return [] }
    let target = sequence(for: state)[0]
    guard source != target else { return [] }
    var frames: [Sprite]
    if let index = blink.firstIndex(of: source) {
      frames = Array(blink[index...])
    } else if let index = turn.firstIndex(of: source) {
      frames = Array(turn[...index].reversed()) + [.blink5]
    } else if let index = run.firstIndex(of: source) {
      // Finish this half-stride at a planted pose before standing still.
      let contact = index <= 2 ? 2 : 5
      frames = Array(run[index...contact]) + [.blink5]
    } else if let index = look.firstIndex(of: source) {
      frames = Array(look[...index].reversed()) + [.blink5]
    } else if let index = settling.firstIndex(of: source) {
      frames = Array(settling[...index].reversed())
    } else {
      frames = [source, .blink5]
    }
    if state == .sleeping {
      frames += settling.dropFirst()
    } else if state == .walking || state == .busy {
      frames += [.run5, .run0]
    }
    return frames
  }

  static func previewIndex(for state: RunnerCompanionState) -> Int {
    switch state {
    case .stretching: 6
    case .charging: 6
    case .happy: 4
    default: 0
    }
  }

  static func frames(for state: RunnerCompanionState, scale: CGFloat) -> [CGImage] {
    frames(for: sequence(for: state), scale: scale)
  }

  static func frames(for sprites: [Sprite], scale: CGFloat) -> [CGImage] {
    sprites.compactMap { frame(sprite: $0, scale: scale) }
  }

  static func frame(state: RunnerCompanionState, index: Int, scale: CGFloat) -> CGImage? {
    let sequence = sequence(for: state)
    let index = state.loops ? ((index % sequence.count) + sequence.count) % sequence.count : min(sequence.count - 1, max(0, index))
    return frame(sprite: sequence[index], scale: scale)
  }

  static func frame(sprite: Sprite, scale: CGFloat) -> CGImage? {
    let scale = scale.isFinite ? max(1, scale) : 1
    let key = "\(sprite.rawValue):\(scale)" as NSString
    if let image = frameCache.images.object(forKey: key) { return image }
    // The medium-resolution sheet keeps transparent padding and original poses.
    let top = sprite == .asleep ? 13 : 9
    let crop = CGRect(x: (sprite.rawValue % 4) * 80, y: (sprite.rawValue / 4) * 80 + top,
                      width: 80, height: 62)
    guard let spriteImage = source?.cropping(to: crop),
          let context = CGContext(data: nil, width: Int(size.width * scale), height: Int(size.height * scale),
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    context.interpolationQuality = .none
    // The sheet is five eighths of the original resolution.
    context.scaleBy(x: scale / 2.8125, y: scale / 2.8125)
    context.draw(spriteImage, in: CGRect(x: -6.25, y: 0, width: 80, height: 62))
    guard let image = context.makeImage() else { return nil }
    frameCache.images.setObject(image, forKey: key, cost: image.bytesPerRow * image.height)
    return image
  }
}
