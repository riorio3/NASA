import SwiftUI

struct SavedPatentsView: View {
    @EnvironmentObject var patentStore: PatentStore

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if patentStore.savedPatents.isEmpty {
                    emptyView
                } else {
                    patentsGrid
                }
            }
            .navigationTitle("Saved Patents")
        }
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bookmark")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("No Saved Patents")
                .font(.title2.bold())

            Text("Patents you save will appear here for quick access")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var patentsGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(patentStore.savedPatents) { patent in
                    NavigationLink(value: patent) {
                        PatentCardView(patent: patent)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .navigationDestination(for: Patent.self) { patent in
                PatentDetailView(patent: patent)
            }
        }
    }
}

#Preview {
    SavedPatentsView()
        .environmentObject(PatentStore())
}
