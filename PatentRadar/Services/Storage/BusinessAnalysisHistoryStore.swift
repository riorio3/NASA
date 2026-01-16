import Foundation

// MARK: - History Entry Model

struct BusinessAnalysisHistoryEntry: Identifiable, Codable {
    let id: UUID
    let patent: Patent
    let analysis: BusinessAnalysis
    let date: Date

    init(patent: Patent, analysis: BusinessAnalysis) {
        self.id = UUID()
        self.patent = patent
        self.analysis = analysis
        self.date = Date()
    }
}

// MARK: - History Store

class BusinessAnalysisHistoryStore: ObservableObject {
    static let shared = BusinessAnalysisHistoryStore()

    @Published var history: [BusinessAnalysisHistoryEntry] = []

    private let storageKey = "businessAnalysisHistory"
    private let maxHistoryItems = 50

    private init() {
        // Defer loading to background to not block app launch
        Task.detached(priority: .userInitiated) { [weak self] in
            let entries = Self.loadHistoryFromDisk()
            await MainActor.run {
                self?.history = entries
            }
        }
    }

    private static func loadHistoryFromDisk() -> [BusinessAnalysisHistoryEntry] {
        guard let data = UserDefaults.standard.data(forKey: "businessAnalysisHistory"),
              let entries = try? JSONDecoder().decode([BusinessAnalysisHistoryEntry].self, from: data) else {
            return []
        }
        return entries
    }

    func addEntry(patent: Patent, analysis: BusinessAnalysis) {
        let entry = BusinessAnalysisHistoryEntry(
            patent: patent,
            analysis: analysis
        )

        // Add to beginning of list
        history.insert(entry, at: 0)

        // Keep only recent items
        if history.count > maxHistoryItems {
            history = Array(history.prefix(maxHistoryItems))
        }

        saveHistory()
    }

    func deleteEntry(_ entry: BusinessAnalysisHistoryEntry) {
        history.removeAll { $0.id == entry.id }
        saveHistory()
    }

    func clearHistory() {
        history = []
        saveHistory()
    }

    func entriesForPatent(_ patentId: String) -> [BusinessAnalysisHistoryEntry] {
        history.filter { $0.patent.id == patentId }
    }


    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(history)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            // Silent fail
        }
    }
}
