import Foundation

enum PasterSearch {
  struct Query {
    private let terms: [String]

    init(_ text: String) {
      terms = text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }

    var isEmpty: Bool { terms.isEmpty }

    func matches(content: String?, sourceAppPath: String) -> Bool {
      guard !isEmpty else { return true }
      let appName = sourceAppPath == "Unknown" ? nil : URL(fileURLWithPath: sourceAppPath)
        .deletingPathExtension().lastPathComponent
      return terms.allSatisfy { term in
        (content?.localizedStandardContains(term) ?? false) ||
          (appName?.localizedStandardContains(term) ?? false)
      }
    }
  }

  static func pageRange(page: Int, count: Int, pageSize: Int) -> Range<Int> {
    guard page >= 0, count > 0, pageSize > 0,
          page <= (count - 1) / pageSize else { return 0..<0 }
    let start = page * pageSize
    return start..<min(start + pageSize, count)
  }
}
