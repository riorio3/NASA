import SwiftUI

struct BusinessAnalysisHistoryView: View {
    @ObservedObject private var historyStore = BusinessAnalysisHistoryStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedEntry: BusinessAnalysisHistoryEntry?

    var body: some View {
        NavigationStack {
            Group {
                if historyStore.history.isEmpty {
                    emptyState
                } else {
                    historyList
                }
            }
            .navigationTitle("Analysis History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                if !historyStore.history.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button(role: .destructive) {
                                historyStore.clearHistory()
                            } label: {
                                Label("Clear All History", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(item: $selectedEntry) { entry in
                BusinessAnalysisView(analysis: entry.analysis, patent: entry.patent)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Analysis History")
                .font(.headline)

            Text("Business analyses you generate will appear here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var historyList: some View {
        List {
            ForEach(historyStore.history) { entry in
                BusinessAnalysisEntryRow(entry: entry)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedEntry = entry
                    }
            }
            .onDelete(perform: deleteEntries)
        }
        .listStyle(.plain)
    }

    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            historyStore.deleteEntry(historyStore.history[index])
        }
    }
}

// MARK: - Business Analysis Entry Row

struct BusinessAnalysisEntryRow: View {
    let entry: BusinessAnalysisHistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Patent title
            Text(entry.patent.title)
                .font(.headline)
                .lineLimit(2)

            // Summary info
            HStack(spacing: 16) {
                Label("\(entry.analysis.businessIdeas.count) ideas", systemImage: "lightbulb")
                Label("\(entry.analysis.targetMarkets.count) markets", systemImage: "chart.pie")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            // Date
            HStack {
                Text(entry.date, style: .date)
                Text("at")
                Text(entry.date, style: .time)
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    BusinessAnalysisHistoryView()
}
