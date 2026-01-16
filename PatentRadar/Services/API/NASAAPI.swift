import Foundation

class NASAAPI {
    static let shared = NASAAPI()

    private let baseURL = "https://technology.nasa.gov"
    private let session: URLSession

    // MARK: - Cache Configuration
    private let categoryCacheSeconds: TimeInterval = 300      // 5 minutes for categories
    private let searchCacheSeconds: TimeInterval = 180        // 3 minutes for search
    private let detailCacheSeconds: TimeInterval = 600        // 10 minutes for details

    // MARK: - Response Caches
    private var categoryCache: [String: (patents: [Patent], time: Date)] = [:]
    private var searchCache: [String: (patents: [Patent], time: Date)] = [:]
    private var detailCache: [String: (detail: PatentDetail, time: Date)] = [:]

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
    }

    // MARK: - Browse Patents by Category
    func browsePatents(category: PatentCategory = .all) async throws -> [Patent] {
        try Task.checkCancellation()

        if category == .all {
            return try await fetchAllCategories()
        }

        guard let slug = category.apiSlug else { return [] }

        // Check cache first
        if let cached = categoryCache[slug],
           Date().timeIntervalSince(cached.time) < categoryCacheSeconds {
            return cached.patents
        }

        let patents = try await fetchCategoryFromNetwork(slug: slug)
        if !patents.isEmpty {
            categoryCache[slug] = (patents, Date())
        }
        return patents
    }

    // MARK: - Fetch Single Category from Network
    private func fetchCategoryFromNetwork(slug: String) async throws -> [Patent] {
        try Task.checkCancellation()

        let urlString = "\(baseURL)/searchosapicat/multi/aw/patent/\(slug)/1/200/"
        guard let url = URL(string: urlString) else {
            throw NASAAPIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        try Task.checkCancellation()

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NASAAPIError.invalidResponse
        }

        let results = try JSONDecoder().decode([ElasticSearchResult].self, from: data)

        return results.compactMap { result -> Patent? in
            guard let title = result.source.title, !title.isEmpty else { return nil }

            let imageURL: String?
            if let img = result.source.img1, !img.isEmpty {
                imageURL = img.hasPrefix("http") ? img : "\(baseURL)\(img)"
            } else {
                imageURL = nil
            }

            var desc = result.source.abstract ?? ""
            if let tech = result.source.techDesc, !tech.isEmpty, !desc.contains(tech.prefix(50)) {
                desc += desc.isEmpty ? tech : "\n\n\(tech)"
            }

            return Patent(
                id: result.id,
                title: title,
                description: desc,
                category: result.source.category ?? "General",
                caseNumber: result.source.clientRecordId ?? result.id,
                patentNumber: result.source.patentNumber,
                imageURL: imageURL,
                center: result.source.center,
                trl: result.source.trl
            )
        }
    }

    // MARK: - Fetch All Categories Combined
    private func fetchAllCategories() async throws -> [Patent] {
        try Task.checkCancellation()

        let cacheKey = "all"

        // Return cached data if valid
        if let cached = categoryCache[cacheKey],
           Date().timeIntervalSince(cached.time) < categoryCacheSeconds {
            return cached.patents
        }

        let slugs = PatentCategory.allCases.compactMap { $0 != .all ? $0.apiSlug : nil }

        var allPatents: [String: Patent] = [:]

        // Fetch in batches of 3 to avoid overwhelming network
        let batchSize = 3
        for batchStart in stride(from: 0, to: slugs.count, by: batchSize) {
            try Task.checkCancellation()

            let batchEnd = min(batchStart + batchSize, slugs.count)
            let batch = Array(slugs[batchStart..<batchEnd])

            try await withThrowingTaskGroup(of: [Patent].self) { group in
                for slug in batch {
                    group.addTask {
                        try await self.fetchCategoryFromNetwork(slug: slug)
                    }
                }

                for try await patents in group {
                    for patent in patents {
                        if allPatents[patent.id] == nil {
                            allPatents[patent.id] = patent
                        }
                    }
                }
            }
        }

        let patents = Array(allPatents.values).sorted { $0.title < $1.title }
        categoryCache[cacheKey] = (patents, Date())
        return patents
    }

    // MARK: - Search Patents
    func searchPatents(query: String, page: Int = 1) async throws -> [Patent] {
        try Task.checkCancellation()

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { throw NASAAPIError.noResults }

        let cacheKey = "\(trimmedQuery.lowercased())_\(page)"

        // Check cache first
        if let cached = searchCache[cacheKey],
           Date().timeIntervalSince(cached.time) < searchCacheSeconds {
            return cached.patents
        }

        let encodedQuery = trimmedQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmedQuery
        let urlString = "\(baseURL)/api/api/patent/\(encodedQuery)?page=\(page)"

        guard let url = URL(string: urlString) else {
            throw NASAAPIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        try Task.checkCancellation()

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NASAAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw NASAAPIError.httpError(httpResponse.statusCode)
        }

        let apiResponse = try JSONDecoder().decode(NASAPatentResponse.self, from: data)
        let patents = apiResponse.toPatents()
        searchCache[cacheKey] = (patents, Date())
        return patents
    }

    // MARK: - Get Patent Detail
    func getPatentDetail(caseNumber: String) async throws -> PatentDetail {
        try Task.checkCancellation()

        // Check cache first
        if let cached = detailCache[caseNumber],
           Date().timeIntervalSince(cached.time) < detailCacheSeconds {
            return cached.detail
        }

        let urlString = "\(baseURL)/patent/\(caseNumber)"
        guard let url = URL(string: urlString) else {
            throw NASAAPIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        try Task.checkCancellation()

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NASAAPIError.invalidResponse
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw NASAAPIError.invalidResponse
        }

        let detail = parsePatentDetail(html: html, caseNumber: caseNumber)
        detailCache[caseNumber] = (detail, Date())
        return detail
    }

    // MARK: - Cache Management
    func clearCache() {
        categoryCache.removeAll()
        searchCache.removeAll()
        detailCache.removeAll()
    }

    func clearCategoryCache() {
        categoryCache.removeAll()
    }

    func clearSearchCache() {
        searchCache.removeAll()
    }

    // MARK: - HTML Parser
    private func parsePatentDetail(html: String, caseNumber: String) -> PatentDetail {
        let title = extractMatch(from: html, pattern: "<h1[^>]*>([^<]+)</h1>") ?? caseNumber

        var abstract = extractMatch(from: html, pattern: "<div class=\"abstract body-text\">(.*?)</div>") ?? ""
        abstract = cleanHTML(abstract)

        var techDesc = extractMatch(from: html, pattern: "<div class=\"tech_desc body-text\">(.*?)</div>") ?? ""
        techDesc = cleanHTML(techDesc)

        var descriptionParts: [String] = []
        if !abstract.isEmpty { descriptionParts.append(abstract) }
        if !techDesc.isEmpty && techDesc != abstract { descriptionParts.append(techDesc) }
        let description = descriptionParts.joined(separator: "\n\n")

        let benefitsSection = extractMatch(from: html, pattern: "<div class=\"benefits\">(.*?)</div>\\s*(?:</div>|<hr)") ?? ""
        let benefits = extractListItems(from: benefitsSection)

        let appsSection = extractMatch(from: html, pattern: "<div class=\"applications\">(.*?)</div>\\s*(?:</div>|<hr)") ?? ""
        let applications = extractListItems(from: appsSection)

        let images = extractMatches(from: html, pattern: "src=\"(https://technology\\.nasa\\.gov/t2media/tops/img/[^\"]+)\"")

        // YouTube videos only
        var videos: [String] = []
        let youtubeEmbedIDs = extractMatches(from: html, pattern: "src=[\"']https?://(?:www\\.)?youtube\\.com/embed/([^\"'?]+)")
        let youtubeWatchIDs = extractMatches(from: html, pattern: "href=[\"']https?://(?:www\\.)?youtube\\.com/watch\\?v=([^\"'&]+)")
        for videoID in Set(youtubeEmbedIDs + youtubeWatchIDs) {
            videos.append("https://www.youtube.com/watch?v=\(videoID)")
        }

        let patentNumbers = extractMatches(from: html, pattern: ">([0-9,D][0-9,]+)</a>")
            .map { $0.replacingOccurrences(of: ",", with: "") }
            .filter { $0.count >= 6 }

        let relatedSection = extractMatch(from: html, pattern: "<div class=\"related\">(.*?)</div>") ?? ""
        let related = extractMatches(from: relatedSection, pattern: "href=\"/patent/([^\"]+)\"")

        return PatentDetail(
            id: caseNumber,
            caseNumber: caseNumber,
            title: title,
            fullDescription: description,
            benefits: benefits,
            applications: applications,
            images: images,
            videos: videos,
            patentNumbers: patentNumbers,
            relatedTechnologies: related
        )
    }

    // MARK: - Regex Helpers
    private func extractMatch(from text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range])
    }

    private func extractMatches(from text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else {
            return []
        }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return matches.compactMap { match in
            guard match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[range])
        }
    }

    private func extractListItems(from text: String) -> [String] {
        let items = extractMatches(from: text, pattern: "<li>([^<]+)</li>")
        return items.map { cleanHTML($0) }.filter { !$0.isEmpty }
    }

    private func cleanHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#039;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Errors
enum NASAAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case noResults

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response from server"
        case .httpError(let code): return "Server error: \(code)"
        case .noResults: return "No patents found"
        }
    }
}
