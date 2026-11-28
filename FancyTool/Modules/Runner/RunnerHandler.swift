import AppKit

@MainActor
final class RunnerHandler: ObservableObject {
  static let shared = RunnerHandler()
  @Published private(set) var cachedRunners: [RunnerModel] = []
  @Published private(set) var isImporting = false
  @Published var importError: String?
  private let store = RunnerStore()
  private var catalogLoaded = false
  private var catalogLoading = false

  private init() {
    let selectedID = AppState.shared.runnerId
    store.load(selectedID: selectedID) { [weak self] result in
      self?.receive(result, validateSelection: AppState.shared.runnerId == selectedID)
      Runner.shared.change()
    }
  }

  func getRunnerById(_ id: String) -> RunnerModel? {
    cachedRunners.first { $0.id.uuidString == id }
  }

  func loadCatalog() {
    guard !catalogLoaded, !catalogLoading else { return }
    catalogLoading = true
    store.load(includeAllDefaults: true) { [weak self] result in
      guard let self else { return }
      self.catalogLoading = false
      if case .success = result { self.catalogLoaded = true }
      self.receive(result)
    }
  }

  func prepareRunner(id: String) async -> RunnerModel? {
    guard !id.isEmpty else { return nil }
    return await withCheckedContinuation { continuation in
      store.load(selectedID: id) { [weak self] result in
        guard let self else { continuation.resume(returning: nil); return }
        self.receive(result, validateSelection: AppState.shared.runnerId == id)
        if case .success(let runners) = result {
          continuation.resume(returning: runners.first { $0.id.uuidString == id })
        } else { continuation.resume(returning: nil) }
      }
    }
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

  private func receive(_ result: Result<[RunnerModel], Error>, validateSelection: Bool = true) {
    switch result {
    case .success(let runners):
      if !cachedRunners.elementsEqual(runners, by: {
        $0.id == $1.id && $0.isDefault == $1.isDefault && $0.frameNumber == $1.frameNumber
          && $0.dataFileName == $1.dataFileName && $0.createdAt == $1.createdAt
      }) { cachedRunners = runners }
      let selectedID = AppState.shared.runnerId
      if validateSelection, !selectedID.isEmpty && !runners.contains(where: { $0.id.uuidString == selectedID }) {
        AppState.shared.runnerId = ""
        Runner.shared.change()
      }
    case .failure(let error): importError = error.localizedDescription
    }
  }
}
