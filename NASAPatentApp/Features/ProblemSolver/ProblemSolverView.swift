import SwiftUI

struct ProblemSolverView: View {
    @EnvironmentObject var patentStore: PatentStore
    @State private var problemText = ""
    @State private var isSearching = false
    @State private var searchPhase = ""
    @State private var solution: ProblemSolution?
    @State private var matchedPatents: [Patent] = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if solution == nil && !isSearching {
                        welcomeSection
                    }

                    inputSection

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
            .navigationTitle("Problem Solver")
            .toolbar {
                if solution != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("New Search") {
                            resetSearch()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Welcome Section

    private var welcomeSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "lightbulb.max.fill")
                .font(.system(size: 56))
                .foregroundStyle(.yellow)

            Text("Solve Problems with NASA Tech")
                .font(.title2.bold())

            Text("Describe a challenge you're facing, and AI will search NASA's patent database to find technologies that could help.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Example prompts
            VStack(alignment: .leading, spacing: 12) {
                Text("Try asking:")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                ForEach(examplePrompts, id: \.self) { prompt in
                    Button {
                        problemText = prompt
                    } label: {
                        HStack {
                            Image(systemName: "text.bubble")
                                .font(.caption)
                            Text(prompt)
                                .font(.caption)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
        }
        .padding(.vertical, 20)
    }

    private var examplePrompts: [String] {
        [
            "I need to keep electronics cool in a sealed enclosure",
            "How can I purify water without chemicals?",
            "I want to detect structural damage in buildings",
            "I need lightweight but strong materials for drones"
        ]
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                TextField("Describe your problem...", text: $problemText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...6)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Button {
                    Task { await searchForSolutions() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(problemText.isEmpty ? .gray : .blue)
                }
                .disabled(problemText.isEmpty || isSearching)
            }
        }
    }

    // MARK: - Loading Section

    private var loadingSection: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text(searchPhase)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Error Section

    private func errorSection(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
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
        .padding(.vertical, 20)
    }

    // MARK: - Results Section

    private func resultsSection(_ solution: ProblemSolution) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            // Summary card
            VStack(alignment: .leading, spacing: 12) {
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

            // Matched patents
            if !solution.matches.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Matching Patents")
                        .font(.headline)

                    ForEach(Array(solution.matches.enumerated()), id: \.offset) { index, match in
                        if match.patentIndex < matchedPatents.count {
                            let patent = matchedPatents[match.patentIndex]
                            NavigationLink(value: patent) {
                                PatentMatchCard(patent: patent, match: match)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .navigationDestination(for: Patent.self) { patent in
                    PatentDetailView(patent: patent)
                }
            } else {
                noMatchesView
            }

            // Additional suggestions
            if !solution.additionalSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lightbulb")
                            .foregroundStyle(.yellow)
                        Text("Additional Suggestions")
                            .font(.subheadline.bold())
                    }

                    Text(solution.additionalSuggestions)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var noMatchesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("No matching patents found")
                .font(.subheadline)

            Text("Try rephrasing your problem or being more specific about the technical challenge.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Actions

    private func searchForSolutions() async {
        guard !problemText.isEmpty else { return }

        isSearching = true
        errorMessage = nil
        solution = nil
        matchedPatents = []

        do {
            // Phase 1: Extract search terms
            searchPhase = "Analyzing your problem..."
            let keywords = try await AIService.shared.extractSearchTerms(from: problemText)

            // Phase 2: Search NASA patents
            searchPhase = "Searching NASA patents..."
            var allPatents: [Patent] = []
            for keyword in keywords.prefix(4) {
                do {
                    let results = try await NASAAPI.shared.searchPatents(query: keyword)
                    allPatents.append(contentsOf: results)
                } catch {
                    continue
                }
            }

            // Remove duplicates
            let uniquePatents = Array(Set(allPatents))
            matchedPatents = uniquePatents

            guard !uniquePatents.isEmpty else {
                solution = ProblemSolution(
                    problem: problemText,
                    summary: "No patents found matching your search. Try describing your problem differently.",
                    matches: [],
                    additionalSuggestions: "Consider breaking down your problem into specific technical challenges, or try searching for related technologies."
                )
                isSearching = false
                return
            }

            // Phase 3: AI analysis
            searchPhase = "Finding relevant solutions..."
            solution = try await AIService.shared.findPatentsForProblem(problemText, patents: uniquePatents)

        } catch {
            errorMessage = error.localizedDescription
        }

        isSearching = false
    }

    private func resetSearch() {
        withAnimation {
            problemText = ""
            solution = nil
            matchedPatents = []
            errorMessage = nil
        }
    }
}

// MARK: - Patent Match Card

struct PatentMatchCard: View {
    let patent: Patent
    let match: PatentMatch

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(patent.title)
                    .font(.subheadline.bold())
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer()

                // Relevance score
                Text("\(match.relevanceScore)%")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(scoreColor)
                    .clipShape(Capsule())
            }

            // Category
            HStack(spacing: 4) {
                Image(systemName: patent.categoryIcon)
                    .font(.caption)
                Text(patent.category)
                    .font(.caption)
            }
            .foregroundStyle(.secondary)

            // Explanation
            Text(match.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            // Application idea
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                Text(match.applicationIdea)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
            .padding(8)
            .background(Color.yellow.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // View details hint
            HStack {
                Spacer()
                Text("Tap to view details")
                    .font(.caption2)
                    .foregroundStyle(.blue)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }

    private var scoreColor: Color {
        if match.relevanceScore >= 80 {
            return .green
        } else if match.relevanceScore >= 70 {
            return .blue
        } else {
            return .orange
        }
    }
}

#Preview {
    ProblemSolverView()
        .environmentObject(PatentStore())
}
