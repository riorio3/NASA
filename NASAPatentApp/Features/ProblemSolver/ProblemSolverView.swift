import SwiftUI

struct ProblemSolverView: View {
    @EnvironmentObject var patentStore: PatentStore
    @State private var problemText = ""
    @State private var isSearching = false
    @State private var searchPhase = ""
    @State private var solution: ProblemSolution?
    @State private var matchedPatents: [Patent] = []
    @State private var errorMessage: String?
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
                ToolbarItem(placement: .topBarTrailing) {
                    if solution != nil || errorMessage != nil {
                        Button("Clear") {
                            resetSearch()
                        }
                    }
                }
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            isInputFocused = false
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

    private var examplePrompts: [String] {
        [
            "I need to cool electronics without fans",
            "How can I purify water without chemicals?",
            "Detect cracks in structures automatically"
        ]
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

            Button {
                isInputFocused = false
                Task { await searchForSolutions() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(problemText.isEmpty || isSearching ? .gray : .blue)
            }
            .disabled(problemText.isEmpty || isSearching)
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
            for keyword in keywords.prefix(4) {
                if let results = try? await NASAAPI.shared.searchPatents(query: keyword) {
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
            solution = try await AIService.shared.findPatentsForProblem(problemText, patents: uniquePatents)

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

#Preview {
    ProblemSolverView()
        .environmentObject(PatentStore())
}
