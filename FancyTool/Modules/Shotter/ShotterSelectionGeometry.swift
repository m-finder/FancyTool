import CoreGraphics

enum ShotterSelectionGeometry {
  struct Screen {
    let frame: CGRect
    let scale: CGFloat
  }

  /// Keeps drag anchors in global AppKit points, including negative positions
  /// on displays to the left or below the primary display.
  struct Drag {
    private(set) var start: CGPoint
    private(set) var end: CGPoint
    private var pointer: CGPoint

    init(at point: CGPoint) {
      start = point
      end = point
      pointer = point
    }

    var rect: CGRect {
      ShotterSelectionGeometry.rect(from: start, to: end)
    }

    mutating func update(to point: CGPoint, square: Bool, moving: Bool) {
      if moving {
        let delta = CGSize(width: point.x - pointer.x, height: point.y - pointer.y)
        start.x += delta.width
        start.y += delta.height
        end.x += delta.width
        end.y += delta.height
      } else {
        end = ShotterSelectionGeometry.endpoint(from: start, to: point, square: square)
      }
      pointer = point
    }
  }

  static func endpoint(from start: CGPoint, to point: CGPoint, square: Bool) -> CGPoint {
    guard square else { return point }
    let dx = point.x - start.x, dy = point.y - start.y
    let length = max(abs(dx), abs(dy))
    return CGPoint(x: start.x + (dx < 0 ? -length : length),
                   y: start.y + (dy < 0 ? -length : length))
  }

  static func rect(from start: CGPoint, to end: CGPoint) -> CGRect {
    // Snap the origin and dimensions independently. Expanding each edge can
    // turn a fractional square into a rectangle or change its size while moving.
    return CGRect(x: min(start.x, end.x).rounded(), y: min(start.y, end.y).rounded(),
                  width: abs(end.x - start.x).rounded(), height: abs(end.y - start.y).rounded())
  }

  /// Region capture composites all intersected displays at the largest native
  /// scale. Match that output policy instead of labelling logical points as px.
  static func pixelSize(for rect: CGRect, screens: [Screen]) -> CGSize {
    let scale = screens.lazy.filter {
      !$0.frame.intersection(rect).isNull && !$0.frame.intersection(rect).isEmpty
    }.map { $0.scale.isFinite ? max(1, $0.scale) : 1 }.max() ?? 1
    return CGSize(width: max(0, (rect.width * scale).rounded(.up)),
                  height: max(0, (rect.height * scale).rounded(.up)))
  }
}
