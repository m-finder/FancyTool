import AppKit

@MainActor
final class RunnerHandler: ObservableObject {
  static let shared = RunnerHandler()
  @Published private(set) var cachedRunners: [RunnerModel] = []
  @Published private(set) var isImporting = false
  @Published var importError: String?
  private let store = RunnerStore()

  private init() {
    store.load { [weak self] result in
      self?.receive(result)
      Runner.shared.change()
    }
  }

  func getRunnerById(_ id: String) -> RunnerModel? {
    cachedRunners.first { $0.id.uuidString == id }
  }

  func addRunner(url: URL) {
    guard !isImporting else { return }
    isImporting = true
    store.add(url: url) { [weak self] result in
      self?.isImporting = false
      self?.receive(result)
    }
  }

  func removeRunner(id: UUID) {
    store.remove(id: id) { [weak self] result in
      self?.receive(result)
      if case .success = result, AppState.shared.runnerId == id.uuidString {
        AppState.shared.runnerId = ""
        Runner.shared.change()
      }
    }
  }

  private func receive(_ result: Result<[RunnerModel], Error>) {
    switch result {
    case .success(let runners):
      cachedRunners = runners
      let selectedID = AppState.shared.runnerId
      if !selectedID.isEmpty && !runners.contains(where: { $0.id.uuidString == selectedID }) {
        AppState.shared.runnerId = ""
        Runner.shared.change()
      }
    case .failure(let error): importError = error.localizedDescription
    }
  }
}
