import SwiftUI

struct PatentDetailView: View {
    let patent: Patent
    @EnvironmentObject var patentStore: PatentStore
    @State private var showAnalysis = false
    @State private var showHistory = false
    @State private var analysis: BusinessAnalysis?
    @State private var isAnalyzing = false
    @State private var analysisError: String?

    // Rich detail state
    @State private var detail: PatentDetail?
    @State private var isLoadingDetail = true
    @State private var selectedMediaIndex = 0

    // Full screen media state
    @State private var showFullScreenImage = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Image Gallery
                imageGallery

                VStack(alignment: .leading, spacing: 20) {
                    // Title & Category
                    titleSection

                    // Quick Stats
                    statsRow

                    // Patent Numbers (if available)
                    if let detail = detail, !detail.patentNumbers.isEmpty {
                        patentNumbersSection(detail.patentNumbers)
                    }

                    Divider()

                    // Description
                    descriptionSection

                    // Benefits (if available)
                    if let detail = detail, !detail.benefits.isEmpty {
                        Divider()
                        benefitsSection(detail.benefits)
                    }

                    // Applications (if available)
                    if let detail = detail, !detail.applications.isEmpty {
                        Divider()
                        applicationsSection(detail.applications)
                    }

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
        .sheet(isPresented: $showHistory) {
            BusinessAnalysisHistoryView()
        }
        .fullScreenCover(isPresented: $showFullScreenImage) {
            FullScreenImageViewer(
                images: mediaImages,
                selectedIndex: $selectedMediaIndex,
                isPresented: $showFullScreenImage
            )
        }
        .task {
            await loadDetail()
        }
    }

    // MARK: - Computed Media Arrays

    private var mediaImages: [String] {
        detail?.images ?? (patent.imageURL.map { [$0] } ?? [])
    }

    private var mediaVideos: [String] {
        detail?.videos ?? []
    }

    private var allMedia: [MediaItem] {
        var items: [MediaItem] = mediaImages.map { .image($0) }
        items.append(contentsOf: mediaVideos.map { .video($0) })
        return items
    }

    // MARK: - Load Detail

    private func loadDetail() async {
        guard !patent.caseNumber.isEmpty else {
            isLoadingDetail = false
            return
        }

        do {
            let fetchedDetail = try await NASAAPI.shared.getPatentDetail(caseNumber: patent.caseNumber)
            withAnimation(.easeInOut(duration: 0.3)) {
                detail = fetchedDetail
                isLoadingDetail = false
            }
        } catch {
            // Silently fail - we still have basic data
            withAnimation {
                isLoadingDetail = false
            }
        }
    }

    // MARK: - Media Gallery

    private var imageGallery: some View {
        let media = allMedia

        return VStack(spacing: 8) {
            // Main Media Carousel
            TabView(selection: $selectedMediaIndex) {
                if media.isEmpty {
                    headerPlaceholder
                        .tag(0)
                } else {
                    ForEach(Array(media.enumerated()), id: \.offset) { index, item in
                        switch item {
                        case .image(let urlString):
                            imageSlide(urlString: urlString, index: index)
                        case .video(let urlString):
                            videoSlide(urlString: urlString, index: index)
                        }
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: media.count > 1 ? .automatic : .never))
            .frame(height: 220)
            .background(
                LinearGradient(
                    colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipped()

            // Media count indicator
            if media.count > 1 {
                HStack(spacing: 4) {
                    if allMedia[safe: selectedMediaIndex]?.isVideo == true {
                        Image(systemName: "video.fill")
                            .font(.caption2)
                    } else {
                        Image(systemName: "photo")
                            .font(.caption2)
                    }
                    Text("\(selectedMediaIndex + 1) of \(media.count)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            // Tap hint
            if !mediaImages.isEmpty {
                Text("Tap image to zoom")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func imageSlide(urlString: String, index: Int) -> some View {
        Button {
            selectedMediaIndex = index
            showFullScreenImage = true
        } label: {
            if let url = URL(string: urlString) {
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
        .buttonStyle(.plain)
        .tag(index)
    }

    private func videoSlide(urlString: String, index: Int) -> some View {
        VideoThumbnailView(videoURL: urlString, posterURL: mediaImages.first) {
            VideoPlayerHelper.openYouTube(url: urlString)
        }
        .tag(index)
    }

    private var headerPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: patent.categoryIcon)
                .font(.system(size: 60))
            Text("NASA Technology")
                .font(.caption)
        }
        .foregroundStyle(.blue)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Title Section

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

    // MARK: - Stats

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

    // MARK: - Patent Numbers

    private func patentNumbersSection(_ numbers: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "scroll")
                    .foregroundStyle(.blue)
                Text("US Patents (\(numbers.count))")
                    .font(.headline)
            }

            FlowLayout(spacing: 8) {
                ForEach(numbers, id: \.self) { number in
                    if let url = URL(string: "https://patents.google.com/patent/US\(number)") {
                        Link(destination: url) {
                            Text(number)
                                .font(.caption.monospaced())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                    } else {
                        Text(number)
                            .font(.caption.monospaced())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    // MARK: - Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Description")
                .font(.headline)

            if isLoadingDetail {
                // Rocket loading animation while fetching full description
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "airplane")
                            .font(.system(size: 32))
                            .foregroundStyle(.blue)
                            .rotationEffect(.degrees(-45))
                        Text("Loading details...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            } else {
                let displayDescription = (detail?.fullDescription.isEmpty == false)
                    ? detail!.fullDescription
                    : patent.description

                Text(displayDescription)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Benefits

    private func benefitsSection(_ benefits: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                Text("Benefits")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(benefits, id: \.self) { benefit in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                            .padding(.top, 3)
                        Text(benefit)
                            .font(.subheadline)
                    }
                }
            }
        }
    }

    // MARK: - Applications

    private func applicationsSection(_ applications: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.orange)
                Text("Applications")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(applications, id: \.self) { app in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                            .padding(.top, 3)
                        Text(app)
                            .font(.subheadline)
                    }
                }
            }
        }
    }

    // MARK: - Analysis

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

            HStack(spacing: 12) {
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

                Button {
                    showHistory = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title3)
                        .padding()
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            Text("Get AI-powered business ideas, market analysis, and an implementation roadmap")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Licensing

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

    // MARK: - Links

    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("More Information")
                .font(.headline)

            if let detail = detail, !detail.patentNumbers.isEmpty,
               let firstPatent = detail.patentNumbers.first,
               let usptoURL = URL(string: "https://patents.google.com/patent/US\(firstPatent)") {
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
            let result = try await AIService.shared.analyzePatent(patent)
            analysis = result
            // Save to history
            BusinessAnalysisHistoryStore.shared.addEntry(patent: patent, analysis: result)
            showAnalysis = true
        } catch {
            analysisError = error.localizedDescription
        }

        isAnalyzing = false
    }
}

// MARK: - Flow Layout for Patent Numbers

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return (CGSize(width: maxWidth, height: currentY + lineHeight), positions)
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

// MARK: - Safe Array Subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    NavigationStack {
        PatentDetailView(patent: Patent(
            id: "1",
            title: "Advanced Composite Materials for Aerospace Applications",
            description: "A novel composite material system designed for extreme temperature environments.",
            category: "Materials",
            caseNumber: "MSC-TOPS-103",
            patentNumber: nil,
            imageURL: nil,
            center: "JSC",
            trl: "6"
        ))
        .environmentObject(PatentStore())
    }
}
