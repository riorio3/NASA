import SwiftUI

struct BusinessAnalysisView: View {
    let analysis: BusinessAnalysis
    let patent: Patent
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0

    private let nasaLicenseURL = URL(string: "https://technology.nasa.gov/license")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Tab Selector
                    tabSelector

                    // Content based on selected tab
                    Group {
                        switch selectedTab {
                        case 0:
                            businessIdeasSection
                        case 1:
                            marketsSection
                        case 2:
                            competitionSection
                        case 3:
                            roadmapSection
                        case 4:
                            costsSection
                        default:
                            businessIdeasSection
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Business Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                AnalysisTabButton(title: "Ideas", icon: "lightbulb", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                AnalysisTabButton(title: "Markets", icon: "chart.pie", isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
                AnalysisTabButton(title: "Competition", icon: "person.3", isSelected: selectedTab == 2) {
                    selectedTab = 2
                }
                AnalysisTabButton(title: "Roadmap", icon: "map", isSelected: selectedTab == 3) {
                    selectedTab = 3
                }
                AnalysisTabButton(title: "Costs", icon: "dollarsign.circle", isSelected: selectedTab == 4) {
                    selectedTab = 4
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Business Ideas

    private var businessIdeasSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Business Ideas", subtitle: "Potential products and services based on this patent")

            ForEach(analysis.businessIdeas) { idea in
                BusinessIdeaCard(idea: idea)
            }
        }
    }

    // MARK: - Markets

    private var marketsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Target Markets", subtitle: "Industries and customer segments")

            ForEach(analysis.targetMarkets, id: \.self) { market in
                HStack(spacing: 12) {
                    Image(systemName: "target")
                        .foregroundStyle(.blue)
                    Text(market)
                        .font(.body)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Revenue Models
            VStack(alignment: .leading, spacing: 12) {
                Text("Revenue Models")
                    .font(.headline)
                    .padding(.top)

                ForEach(analysis.revenueModels, id: \.self) { model in
                    HStack(spacing: 12) {
                        Image(systemName: "dollarsign.circle")
                            .foregroundStyle(.green)
                        Text(model)
                            .font(.body)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    // MARK: - Competition

    private var competitionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Competition Analysis", subtitle: "Existing players and your advantages")

            ForEach(analysis.competition) { competitor in
                CompetitorCard(competitor: competitor)
            }
        }
    }

    // MARK: - Roadmap

    private var roadmapSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Implementation Roadmap", subtitle: "Steps to bring this to market")

            ForEach(analysis.roadmap) { step in
                RoadmapStepCard(step: step)
            }
        }
    }

    // MARK: - Costs

    private var costsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Cost Estimates", subtitle: "Budget ranges for commercialization")

            CostRow(title: "Prototyping", value: analysis.costEstimates.prototyping, icon: "hammer")
            CostRow(title: "Manufacturing", value: analysis.costEstimates.manufacturing, icon: "building.2")
            CostRow(title: "Marketing", value: analysis.costEstimates.marketing, icon: "megaphone")

            Divider()

            HStack {
                Text("Estimated Total")
                    .font(.headline)
                Spacer()
                Text(analysis.costEstimates.total)
                    .font(.title3.bold())
                    .foregroundStyle(.blue)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Startup NASA callout
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text("Startup NASA Program")
                        .font(.headline)
                }

                Text("Eligible startups can license this technology for FREE for up to 3 years, significantly reducing initial costs.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Link(destination: nasaLicenseURL) {
                    Text("Learn More")
                        .font(.subheadline.bold())
                }
            }
            .padding()
            .background(Color.yellow.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

// MARK: - Supporting Views

struct AnalysisTabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.bold())
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct BusinessIdeaCard: View {
    let idea: BusinessIdea

    var scaleColor: Color {
        switch idea.potentialScale.lowercased() {
        case "large": return .green
        case "medium": return .orange
        default: return .blue
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(idea.name)
                    .font(.headline)
                Spacer()
                Text(idea.potentialScale)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(scaleColor.opacity(0.2))
                    .foregroundStyle(scaleColor)
                    .clipShape(Capsule())
            }

            Text(idea.description)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct CompetitorCard: View {
    let competitor: CompetitorInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(competitor.name)
                .font(.headline)

            Text(competitor.description)
                .font(.body)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Your Advantage:")
                    .font(.subheadline.bold())
            }

            Text(competitor.gap)
                .font(.subheadline)
                .foregroundStyle(.green)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct RoadmapStepCard: View {
    let step: RoadmapStep

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Step Number
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 32, height: 32)
                Text("\(step.step)")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.headline)
                Text(step.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct CostRow: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            Text(title)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    BusinessAnalysisView(
        analysis: BusinessAnalysis(
            patentId: "1",
            businessIdeas: [
                BusinessIdea(name: "Thermal Protection Kits", description: "Consumer-grade thermal protection for outdoor equipment", potentialScale: "Medium"),
                BusinessIdea(name: "Industrial Insulation", description: "High-temp insulation for manufacturing facilities", potentialScale: "Large")
            ],
            targetMarkets: ["Aerospace Industry", "Automotive", "Consumer Electronics"],
            competition: [
                CompetitorInfo(name: "3M Thermal Products", description: "Industrial thermal solutions", gap: "NASA tech handles 40% higher temperatures")
            ],
            revenueModels: ["Product Sales", "Licensing to Manufacturers"],
            roadmap: [
                RoadmapStep(step: 1, title: "Prototype Development", description: "Create initial prototypes using NASA specs"),
                RoadmapStep(step: 2, title: "Testing & Certification", description: "Industry standard testing"),
                RoadmapStep(step: 3, title: "Manufacturing Setup", description: "Partner with manufacturer")
            ],
            costEstimates: CostEstimate(prototyping: "$50K - $100K", manufacturing: "$200K - $500K", marketing: "$50K - $100K", total: "$300K - $700K")
        ),
        patent: Patent(
            id: "1",
            title: "Advanced Composite Materials",
            description: "High-temp materials",
            category: "Materials",
            caseNumber: "ARC-123",
            patentNumber: nil,
            imageURL: nil,
            center: "Ames",
            trl: "6"
        )
    )
}
