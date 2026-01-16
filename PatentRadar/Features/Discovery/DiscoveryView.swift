import SwiftUI

struct DiscoveryView: View {
    @EnvironmentObject var patentStore: PatentStore
    @State private var searchText = ""
    @State private var patents: [Patent] = []
    @State private var isLoading = false
    @State private var selectedCategory: PatentCategory = .all
    @State private var errorMessage: String?
    @State private var hasSearched = false

    private let categories = PatentCategory.allCases
    private let columns = [
        GridItem(.flexible(), spacing: 12, alignment: .top),
        GridItem(.flexible(), spacing: 12, alignment: .top)
    ]
    private let categoryGridColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if hasSearched || !patents.isEmpty {
                    categoryPills
                }

                ScrollView {
                    VStack(spacing: 20) {
                        if isLoading {
                            loadingView
                        } else if let error = errorMessage {
                            errorView(error)
                        } else if patents.isEmpty && hasSearched {
                            emptyView
                        } else if patents.isEmpty {
                            welcomeView
                        } else {
                            patentsGrid
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("")
            .toolbar {
                if hasSearched || !patents.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            goHome()
                        } label: {
                            Image(systemName: "square.grid.2x2")
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search patents...")
            .onSubmit(of: .search) {
                guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                Task { await search() }
            }
            .navigationDestination(for: Patent.self) { patent in
                PatentDetailView(patent: patent)
            }
        }
    }

    private func goHome() {
        withAnimation {
            patents = []
            hasSearched = false
            searchText = ""
            selectedCategory = .all
            errorMessage = nil
        }
    }

    private var categoryPills: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(categories, id: \.self) { category in
                        CategoryPill(
                            category: category,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                            Task { await search() }
                        }
                        .id(category)
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .onAppear {
                proxy.scrollTo(selectedCategory, anchor: .center)
            }
            .onChange(of: selectedCategory) { newCategory in
                withAnimation {
                    proxy.scrollTo(newCategory, anchor: .center)
                }
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Searching patents...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task { await search() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No patents found")
                .font(.headline)
            Text("Try a different search term or category")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var welcomeView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)

                Text("Explore Patents")
                    .font(.title2.bold())

                Text("Search 600+ government patents available for licensing")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            categoryGrid
        }
        .padding(.top, 20)
    }

    private var categoryGrid: some View {
        LazyVGrid(columns: categoryGridColumns, spacing: 12) {
            ForEach(categories, id: \.self) { category in
                CategoryGridItem(category: category) {
                    selectedCategory = category
                    Task { await search() }
                }
            }
        }
    }

    private var patentsGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(patents) { patent in
                NavigationLink(value: patent) {
                    PatentCardView(patent: patent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func search() async {
        isLoading = true
        errorMessage = nil
        hasSearched = true

        await Task.yield()

        do {
            let results: [Patent]
            if searchText.isEmpty {
                results = try await NASAAPI.shared.browsePatents(category: selectedCategory)
            } else {
                results = try await NASAAPI.shared.searchPatents(query: searchText)
            }
            patents = results
        } catch is CancellationError {
            // Ignore
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

struct CategoryGridItem: View {
    let category: PatentCategory
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 24))
                Text(category.shortName)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .padding(8)
            .background(category.color.opacity(0.15))
            .foregroundStyle(category.color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct CategoryPill: View {
    let category: PatentCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.caption)
                Text(category.shortName)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? category.color : Color(.systemGray5))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
    }
}
