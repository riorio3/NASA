import SwiftUI

@main
struct PatentRadarApp: App {
    @StateObject private var patentStore = PatentStore()

    init() {
        // App initialization
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(patentStore)
        }
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            DiscoveryView()
                .tabItem {
                    Label("Discover", systemImage: "magnifyingglass")
                }

            ProblemSolverView()
                .tabItem {
                    Label("Solve", systemImage: "lightbulb")
                }

            SavedPatentsView()
                .tabItem {
                    Label("Saved", systemImage: "bookmark.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .tint(.blue)
    }
}

// MARK: - App State
@MainActor
class PatentStore: ObservableObject {
    @Published var savedPatents: [Patent] = []
    @Published var apiKey: String = ""
    @Published var isReady = false

    private let savedPatentsKey = "savedPatents"

    init() {
        // Defer loading to background to not block app launch
        Task.detached(priority: .userInitiated) { [weak self] in
            let patents = Self.loadSavedPatentsFromDisk()
            let key = KeychainService.shared.getAPIKey() ?? ""

            await MainActor.run {
                self?.savedPatents = patents
                self?.apiKey = key
                self?.isReady = true
            }
        }
    }

    private nonisolated static func loadSavedPatentsFromDisk() -> [Patent] {
        guard let data = UserDefaults.standard.data(forKey: "savedPatents"),
              let patents = try? JSONDecoder().decode([Patent].self, from: data) else {
            return []
        }
        return patents
    }

    func savePatent(_ patent: Patent) {
        if !savedPatents.contains(where: { $0.id == patent.id }) {
            savedPatents.append(patent)
            persistSavedPatents()
        }
    }

    func removePatent(_ patent: Patent) {
        savedPatents.removeAll { $0.id == patent.id }
        persistSavedPatents()
    }

    func isSaved(_ patent: Patent) -> Bool {
        savedPatents.contains { $0.id == patent.id }
    }


    private func persistSavedPatents() {
        if let data = try? JSONEncoder().encode(savedPatents) {
            UserDefaults.standard.set(data, forKey: savedPatentsKey)
        }
    }

    func loadAPIKey() {
        apiKey = KeychainService.shared.getAPIKey() ?? ""
    }

    func setAPIKey(_ key: String) {
        apiKey = key
        KeychainService.shared.saveAPIKey(key)
    }
}
