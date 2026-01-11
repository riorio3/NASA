import Foundation

class NASAAPI {
    static let shared = NASAAPI()

    private let baseURL = "https://technology.nasa.gov/api/api"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
    }

    // MARK: - Search Patents
    func searchPatents(query: String, page: Int = 1) async throws -> [Patent] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { throw NASAAPIError.noResults }

        let encodedQuery = trimmedQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmedQuery
        let urlString = "\(baseURL)/patent/\(encodedQuery)?page=\(page)"

        guard let url = URL(string: urlString) else {
            throw NASAAPIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NASAAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw NASAAPIError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(NASAPatentResponse.self, from: data)

        return apiResponse.toPatents()
    }

    // MARK: - Browse All Patents (by category)
    func browsePatents(category: PatentCategory = .all, page: Int = 1) async throws -> [Patent] {
        // For "All", just search general term
        if category == .all {
            return try await searchPatents(query: "technology", page: page)
        }

        // Search by category name
        let patents = try await searchPatents(query: category.rawValue, page: page)

        // Filter to only include patents that actually match the category
        let filtered = patents.filter { patent in
            let patentCategory = patent.category.lowercased()
            let targetCategory = category.rawValue.lowercased()

            // Exact match or contains the key term
            if patentCategory == targetCategory {
                return true
            }

            // Check for partial matches (e.g., "Health" matches "Health Medicine and Biotechnology")
            let targetWords = targetCategory.components(separatedBy: .whitespaces)
            for word in targetWords where word.count > 3 {
                if patentCategory.contains(word) {
                    return true
                }
            }

            return false
        }

        // If filtering removed everything, return unfiltered (API might have different category names)
        return filtered.isEmpty ? patents : filtered
    }

    // MARK: - Get Featured/Recent Patents
    func getFeaturedPatents() async throws -> [Patent] {
        // Search across popular categories to get a mix
        let queries = ["aeronautics", "robotics", "sensors", "materials", "propulsion"]
        var allPatents: [Patent] = []

        for query in queries {
            do {
                let patents = try await searchPatents(query: query, page: 1)
                allPatents.append(contentsOf: patents.prefix(3))
            } catch {
                continue // Skip failed queries
            }
        }

        return Array(Set(allPatents)).sorted { $0.title < $1.title }
    }

    // MARK: - Get Patent by ID
    func getPatent(id: String) async throws -> Patent? {
        let patents = try await searchPatents(query: id)
        return patents.first { $0.id == id || $0.caseNumber == id }
    }

    // MARK: - Get Patent Detail (Scrapes full page)
    func getPatentDetail(caseNumber: String) async throws -> PatentDetail {
        let urlString = "https://technology.nasa.gov/patent/\(caseNumber)"
        guard let url = URL(string: urlString) else {
            throw NASAAPIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NASAAPIError.invalidResponse
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw NASAAPIError.invalidResponse
        }

        return parsePatentDetail(html: html, caseNumber: caseNumber)
    }

    // MARK: - HTML Parser
    private func parsePatentDetail(html: String, caseNumber: String) -> PatentDetail {
        // Extract title
        let title = extractMatch(from: html, pattern: "<h1[^>]*>([^<]+)</h1>") ?? caseNumber

        // Extract full description
        var description = extractMatch(from: html, pattern: "<div class=\"description\"[^>]*>(.*?)</div>\\s*</div>") ?? ""
        description = cleanHTML(description)

        // Extract benefits
        let benefitsSection = extractMatch(from: html, pattern: "<div class=\"benefits\">(.*?)</div>\\s*</div>") ?? ""
        let benefits = extractListItems(from: benefitsSection)

        // Extract applications
        let appsSection = extractMatch(from: html, pattern: "<div class=\"applications\">(.*?)</div>\\s*</div>") ?? ""
        let applications = extractListItems(from: appsSection)

        // Extract all images (full size, not thumbnails)
        let images = extractMatches(from: html, pattern: "src=\"(https://technology\\.nasa\\.gov/t2media/tops/img/[^\"]+)\"")

        // Extract video URLs - comprehensive patterns
        var videos: [String] = []

        // 1. Direct video files in src attributes
        videos.append(contentsOf: extractMatches(from: html, pattern: "src=[\"']([^\"']+\\.mp4)[\"']"))
        videos.append(contentsOf: extractMatches(from: html, pattern: "src=[\"']([^\"']+\\.m4v)[\"']"))
        videos.append(contentsOf: extractMatches(from: html, pattern: "src=[\"']([^\"']+\\.mov)[\"']"))
        videos.append(contentsOf: extractMatches(from: html, pattern: "src=[\"']([^\"']+\\.webm)[\"']"))

        // 2. Video source tags
        videos.append(contentsOf: extractMatches(from: html, pattern: "<source[^>]+src=[\"']([^\"']+)[\"'][^>]*type=[\"']video/"))

        // 3. AWS S3 URLs (NASA uses ntts-prod.s3.amazonaws.com)
        videos.append(contentsOf: extractMatches(from: html, pattern: "[\"'](https://[^\"']*s3[^\"']*amazonaws\\.com[^\"']+\\.mp4)[\"']"))

        // 4. YouTube embeds - convert to watch URLs
        let youtubeEmbeds = extractMatches(from: html, pattern: "src=[\"']https?://(?:www\\.)?youtube\\.com/embed/([^\"'?]+)")
        for videoID in youtubeEmbeds {
            videos.append("https://www.youtube.com/watch?v=\(videoID)")
        }

        // 5. YouTube watch links (extract full URL)
        videos.append(contentsOf: extractMatches(from: html, pattern: "href=[\"'](https?://(?:www\\.)?youtube\\.com/watch\\?v=[^\"'&]+)[\"']"))

        // 6. YouTube short links
        videos.append(contentsOf: extractMatches(from: html, pattern: "href=[\"'](https?://youtu\\.be/[^\"'?]+)[\"']"))

        // 7. Any href to video files
        videos.append(contentsOf: extractMatches(from: html, pattern: "href=[\"']([^\"']+\\.mp4)[\"']"))

        // Clean up URLs - make relative URLs absolute
        videos = videos.compactMap { url -> String? in
            var cleanURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanURL.isEmpty { return nil }
            // Make relative URLs absolute
            if cleanURL.hasPrefix("/") {
                cleanURL = "https://technology.nasa.gov\(cleanURL)"
            } else if !cleanURL.hasPrefix("http") {
                cleanURL = "https://technology.nasa.gov/\(cleanURL)"
            }
            return cleanURL
        }

        // Remove duplicates
        videos = Array(Set(videos))

        // Extract patent numbers
        let patentNumbers = extractMatches(from: html, pattern: ">([0-9,D][0-9,]+)</a>")
            .map { $0.replacingOccurrences(of: ",", with: "") }
            .filter { $0.count >= 6 }

        // Extract related technologies
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
    case decodingError(Error)
    case noResults

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "Server error: \(code)"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .noResults:
            return "No patents found"
        }
    }
}
