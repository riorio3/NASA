import SwiftUI

@main
struct NASAPatentApp: App {
    @StateObject private var patentStore = PatentStore()

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

    private let savedPatentsKey = "savedPatents"

    init() {
        loadSavedPatents()
        loadAPIKey()
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

    private func loadSavedPatents() {
        if let data = UserDefaults.standard.data(forKey: savedPatentsKey),
           let patents = try? JSONDecoder().decode([Patent].self, from: data) {
            savedPatents = patents
        }
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
