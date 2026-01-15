import SwiftUI

struct ProblemSolverView: View {
    @EnvironmentObject var patentStore: PatentStore
    @StateObject private var historyStore = ProblemHistoryStore.shared
    @State private var problemText = ""
    @State private var isSearching = false
    @State private var searchPhase = ""
    @State private var solution: ProblemSolution?
    @State private var matchedPatents: [Patent] = []
    @State private var errorMessage: String?
    @State private var showHistory = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Scrollable content
                ScrollView {
                    VStack(spacing: 20) {
                        if solution == nil && !isSearching && errorMessage == nil {
                            welcomeSection
                        }

                        if isSearching {
                            loadingSection
                        } else if let error = errorMessage {
                            errorSection(error)
                        } else if let solution = solution {
                            resultsSection(solution)
                        }
                    }
                    .padding()
                }
                .onTapGesture {
                    isInputFocused = false
                }

                Divider()

                // Fixed input at bottom
                inputSection
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
            }
            .navigationTitle("Problem Solver")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .disabled(historyStore.history.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if solution != nil || errorMessage != nil {
                        Button("Clear") {
                            resetSearch()
                        }
                    }
                }
            }
            .sheet(isPresented: $showHistory) {
                HistorySheet(
                    historyStore: historyStore,
                    onSelectEntry: { entry in
                        loadFromHistory(entry)
                        showHistory = false
                    }
                )
            }
        }
    }

    private func loadFromHistory(_ entry: ProblemHistoryEntry) {
        problemText = entry.problem
        solution = entry.solution
        matchedPatents = entry.matchedPatents
        errorMessage = nil
    }

    // MARK: - Welcome Section

    private var welcomeSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "lightbulb.max.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)

            Text("Solve with NASA Tech")
                .font(.title3.bold())

            Text("Describe your challenge and AI will find NASA patents that could help.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Example prompts
            VStack(spacing: 10) {
                Text("Try these:")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(examplePrompts, id: \.self) { prompt in
                    Button {
                        problemText = prompt
                        isInputFocused = true
                    } label: {
                        Text(prompt)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 8)
        }
        .padding(.vertical, 20)
    }

    // All available prompts - rotates every 30 minutes
    private static let allPrompts: [[String]] = [
        [
            "I need to cool electronics without fans",
            "How can I purify water without chemicals?",
            "Detect cracks in structures automatically"
        ],
        [
            "Lightweight materials for drones",
            "Reduce noise in aircraft engines",
            "Monitor air quality in buildings"
        ],
        [
            "Generate power from vibrations",
            "Protect equipment from radiation",
            "Improve battery efficiency"
        ],
        [
            "Filter microplastics from water",
            "Self-healing materials for vehicles",
            "Non-invasive health monitoring"
        ]
    ]

    private var examplePrompts: [String] {
        // Rotate every 30 minutes based on timestamp
        let rotationPeriod: TimeInterval = 1800 // 30 minutes
        let index = Int(Date().timeIntervalSince1970 / rotationPeriod) % Self.allPrompts.count
        return Self.allPrompts[index]
    }

    // MARK: - Input Section

    private var inputSection: some View {
        HStack(spacing: 10) {
            TextField("Describe your problem...", text: $problemText)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .focused($isInputFocused)
                .submitLabel(.search)
                .onSubmit {
                    if !problemText.isEmpty && !isSearching {
                        isInputFocused = false
                        Task { await searchForSolutions() }
                    }
                }
                .accessibilityLabel("Problem description")
                .accessibilityHint("Describe a problem and AI will find NASA patents that could help")

            Button {
                isInputFocused = false
                Task { await searchForSolutions() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(problemText.isEmpty || isSearching ? .gray : .blue)
            }
            .disabled(problemText.isEmpty || isSearching)
            .accessibilityLabel("Find solutions")
            .accessibilityHint("Search NASA patents for solutions to your problem")
        }
    }

    // MARK: - Loading Section

    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text(searchPhase)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Error Section

    private func errorSection(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(.orange)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                Task { await searchForSolutions() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 40)
    }

    // MARK: - Results Section

    private func resultsSection(_ solution: ProblemSolution) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Summary
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.blue)
                    Text("AI Analysis")
                        .font(.headline)
                }

                Text(solution.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Matches
            if !solution.matches.isEmpty {
                Text("Matching Patents")
                    .font(.headline)

                ForEach(Array(solution.matches.enumerated()), id: \.offset) { _, match in
                    if match.patentIndex >= 0 && match.patentIndex < matchedPatents.count {
                        let patent = matchedPatents[match.patentIndex]
                        NavigationLink(value: patent) {
                            PatentMatchCard(patent: patent, match: match)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Navigation destination
                .navigationDestination(for: Patent.self) { patent in
                    PatentDetailView(patent: patent)
                }
            } else {
                noMatchesView
            }

            // Suggestions
            if !solution.additionalSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "lightbulb")
                            .foregroundStyle(.yellow)
                        Text("Tip")
                            .font(.subheadline.bold())
                    }
                    Text(solution.additionalSuggestions)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var noMatchesView: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)

            Text("No matching patents found")
                .font(.subheadline)

            Text("Try rephrasing your problem.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    // MARK: - Actions

    private func searchForSolutions() async {
        guard !problemText.isEmpty else { return }

        isSearching = true
        errorMessage = nil
        solution = nil
        matchedPatents = []

        do {
            searchPhase = "Analyzing problem..."
            let keywords = try await AIService.shared.extractSearchTerms(from: problemText)

            searchPhase = "Searching patents..."
            var allPatents: [Patent] = []

            // Search keywords in parallel to reduce hang time
            await withTaskGroup(of: [Patent].self) { group in
                for keyword in keywords.prefix(4) {
                    group.addTask {
                        (try? await NASAAPI.shared.searchPatents(query: keyword)) ?? []
                    }
                }
                for await results in group {
                    allPatents.append(contentsOf: results)
                }
            }

            let uniquePatents = Array(Set(allPatents))
            matchedPatents = uniquePatents

            guard !uniquePatents.isEmpty else {
                solution = ProblemSolution(
                    problem: problemText,
                    summary: "No patents found. Try different keywords.",
                    matches: [],
                    additionalSuggestions: "Break down your problem into specific technical terms."
                )
                isSearching = false
                return
            }

            searchPhase = "Finding solutions..."
            let result = try await AIService.shared.findPatentsForProblem(problemText, patents: uniquePatents)
            solution = result

            // Save to history
            historyStore.addEntry(
                problem: problemText,
                solution: result,
                matchedPatents: uniquePatents
            )

        } catch {
            errorMessage = error.localizedDescription
        }

        isSearching = false
    }

    private func resetSearch() {
        problemText = ""
        solution = nil
        matchedPatents = []
        errorMessage = nil
        isInputFocused = false
    }
}

// MARK: - Patent Match Card

struct PatentMatchCard: View {
    let patent: Patent
    let match: PatentMatch

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(patent.title)
                    .font(.subheadline.bold())
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer()

                Text("\(match.relevanceScore)%")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(scoreColor)
                    .clipShape(Capsule())
            }

            Text(match.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 4) {
                Image(systemName: "lightbulb.fill")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
                Text(match.applicationIdea)
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(6)
            .background(Color.yellow.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            HStack {
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var scoreColor: Color {
        if match.relevanceScore >= 80 { return .green }
        if match.relevanceScore >= 70 { return .blue }
        return .orange
    }
}

// MARK: - History Sheet

struct HistorySheet: View {
    @ObservedObject var historyStore: ProblemHistoryStore
    let onSelectEntry: (ProblemHistoryEntry) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if historyStore.history.isEmpty {
                    emptyState
                } else {
                    historyList
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !historyStore.history.isEmpty {
                        Button("Clear All", role: .destructive) {
                            historyStore.clearHistory()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No History Yet")
                .font(.headline)

            Text("Your problem solving searches will appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var historyList: some View {
        List {
            ForEach(historyStore.history) { entry in
                Button {
                    onSelectEntry(entry)
                } label: {
                    HistoryEntryRow(entry: entry)
                }
                .buttonStyle(.plain)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    historyStore.deleteEntry(historyStore.history[index])
                }
            }
        }
        .listStyle(.plain)
    }
}

struct HistoryEntryRow: View {
    let entry: ProblemHistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.problem)
                .font(.subheadline.bold())
                .lineLimit(2)

            Text(entry.solution.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack {
                Label("\(entry.solution.matches.count) patents", systemImage: "doc.text")
                    .font(.caption2)
                    .foregroundStyle(.blue)

                Spacer()

                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ProblemSolverView()
        .environmentObject(PatentStore())
}
