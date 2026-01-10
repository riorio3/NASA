import SwiftUI

struct PatentDetailView: View {
    let patent: Patent
    @EnvironmentObject var patentStore: PatentStore
    @State private var showAnalysis = false
    @State private var analysis: BusinessAnalysis?
    @State private var isAnalyzing = false
    @State private var analysisError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header Image
                headerImage

                VStack(alignment: .leading, spacing: 20) {
                    // Title & Category
                    titleSection

                    // Quick Stats
                    statsRow

                    Divider()

                    // Description
                    descriptionSection

                    Divider()

                    // AI Analysis CTA
                    analysisSection

                    Divider()

                    // Licensing Info
                    licensingSection

                    // Links
                    linksSection
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("Patent Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    toggleSave()
                } label: {
                    Image(systemName: patentStore.isSaved(patent) ? "bookmark.fill" : "bookmark")
                }
            }
        }
        .sheet(isPresented: $showAnalysis) {
            if let analysis = analysis {
                BusinessAnalysisView(analysis: analysis, patent: patent)
            }
        }
    }

    // MARK: - Views

    private var headerImage: some View {
        ZStack {
            if let imageURL = patent.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        headerPlaceholder
                    case .empty:
                        ProgressView()
                    @unknown default:
                        headerPlaceholder
                    }
                }
            } else {
                headerPlaceholder
            }
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipped()
    }

    private var headerPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: patent.categoryIcon)
                .font(.system(size: 60))
            Text("NASA Technology")
                .font(.caption)
        }
        .foregroundStyle(.blue)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: patent.categoryIcon)
                Text(patent.category)
            }
            .font(.subheadline)
            .foregroundStyle(.blue)

            Text(patent.title)
                .font(.title2.bold())
        }
    }

    private var statsRow: some View {
        HStack(spacing: 20) {
            StatItem(
                icon: "building.columns",
                label: "Center",
                value: patent.center ?? "NASA"
            )

            if let trl = patent.trl {
                StatItem(
                    icon: "chart.bar",
                    label: "TRL",
                    value: trl
                )
            }

            StatItem(
                icon: "doc.text",
                label: "Case",
                value: patent.caseNumber.isEmpty ? "N/A" : String(patent.caseNumber.prefix(12))
            )
        }
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Description")
                .font(.headline)

            Text(patent.description)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var analysisSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Business Potential")
                .font(.headline)

            if let error = analysisError {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if error.contains("API key") {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Text("Add API Key in Settings")
                            .font(.subheadline)
                    }
                }
            }

            Button {
                Task { await analyzePatent() }
            } label: {
                HStack {
                    if isAnalyzing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(isAnalyzing ? "Analyzing..." : "Analyze with AI")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isAnalyzing)

            Text("Get AI-powered business ideas, market analysis, and an implementation roadmap")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var licensingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Licensing Options")
                .font(.headline)

            VStack(spacing: 12) {
                LicenseOptionRow(
                    title: "Startup NASA",
                    description: "Free for startups - up to 3 years",
                    icon: "star",
                    highlight: true
                )

                LicenseOptionRow(
                    title: "Research License",
                    description: "12-month development & testing",
                    icon: "flask",
                    highlight: false
                )

                LicenseOptionRow(
                    title: "Commercial License",
                    description: "Full manufacturing rights",
                    icon: "building.2",
                    highlight: false
                )
            }

            if let licenseURL = URL(string: "https://technology.nasa.gov/license") {
                Link(destination: licenseURL) {
                    HStack {
                        Text("Start Licensing Application")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("More Information")
                .font(.headline)

            if let usptoURL = patent.usptoURL {
                Link(destination: usptoURL) {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("View Full Patent (USPTO)")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .foregroundStyle(.blue)
                }
            }

            if let portalURL = URL(string: "https://technology.nasa.gov/patent/\(patent.caseNumber)") {
                Link(destination: portalURL) {
                    HStack {
                        Image(systemName: "globe")
                        Text("View on NASA T2 Portal")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .foregroundStyle(.blue)
                }
            }
        }
        .padding(.bottom, 40)
    }

    // MARK: - Actions

    private func toggleSave() {
        if patentStore.isSaved(patent) {
            patentStore.removePatent(patent)
        } else {
            patentStore.savePatent(patent)
        }
    }

    private func analyzePatent() async {
        isAnalyzing = true
        analysisError = nil

        do {
            analysis = try await AIService.shared.analyzePatent(patent)
            showAnalysis = true
        } catch {
            analysisError = error.localizedDescription
        }

        isAnalyzing = false
    }
}

// MARK: - Supporting Views

struct StatItem: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

struct LicenseOptionRow: View {
    let title: String
    let description: String
    let icon: String
    let highlight: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(highlight ? .yellow : .blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if highlight {
                Text("FREE")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.2))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())
            }
        }
        .padding()
        .background(highlight ? Color.blue.opacity(0.05) : Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    NavigationStack {
        PatentDetailView(patent: Patent(
            id: "1",
            title: "Advanced Composite Materials for Aerospace Applications",
            description: "A novel composite material system designed for extreme temperature environments in aerospace applications. This technology enables lightweight structures that can withstand temperatures exceeding 2000 degrees Fahrenheit while maintaining structural integrity.",
            category: "Materials",
            caseNumber: "ARC-14653-2",
            patentNumber: "US9876543",
            imageURL: nil,
            center: "Ames Research Center",
            trl: "6"
        ))
        .environmentObject(PatentStore())
    }
}
