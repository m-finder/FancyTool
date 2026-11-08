/// Stores annotation snapshots only; the captured image is never duplicated.
struct ShotterEditHistory<Value: Equatable> {
  private(set) var value: Value
  private var undoValues: [Value] = []
  private var redoValues: [Value] = []
  private let limit: Int

  init(initial: Value, limit: Int = 100) {
    value = initial
    self.limit = max(1, limit)
  }

  var canUndo: Bool { !undoValues.isEmpty }
  var canRedo: Bool { !redoValues.isEmpty }

  mutating func commit(_ newValue: Value) {
    guard newValue != value else { return }
    undoValues.append(value)
    if undoValues.count > limit { undoValues.removeFirst() }
    value = newValue
    redoValues.removeAll()
  }

  mutating func undo() {
    guard let previous = undoValues.popLast() else { return }
    redoValues.append(value)
    value = previous
  }

  mutating func redo() {
    guard let next = redoValues.popLast() else { return }
    undoValues.append(value)
    value = next
  }
}
