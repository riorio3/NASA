import Foundation

class AIService {
    static let shared = AIService()

    private let apiURL = "https://api.anthropic.com/v1/messages"
    private let model = "claude-sonnet-4-20250514"

    private init() {}

    // MARK: - Analyze Patent for Business Potential
    func analyzePatent(_ patent: Patent) async throws -> BusinessAnalysis {
        guard let apiKey = KeychainService.shared.getAPIKey(), !apiKey.isEmpty else {
            throw AIServiceError.noAPIKey
        }

        let prompt = buildAnalysisPrompt(for: patent)
        let response = try await sendRequest(prompt: prompt, apiKey: apiKey)
        return try parseAnalysisResponse(response, patentId: patent.id)
    }

    private func buildAnalysisPrompt(for patent: Patent) -> String {
        """
        You are a business strategist analyzing NASA technology for commercialization potential.

        PATENT INFORMATION:
        Title: \(patent.title)
        Description: \(patent.description)
        Category: \(patent.category)
        NASA Case Number: \(patent.caseNumber)
        Technology Readiness Level: \(patent.trl ?? "Unknown")

        Analyze this NASA patent and provide a comprehensive business analysis. Return your response in the following JSON format exactly:

        {
            "businessIdeas": [
                {"name": "Idea Name", "description": "What the business would do", "potentialScale": "Small/Medium/Large"}
            ],
            "targetMarkets": ["Market 1", "Market 2", "Market 3"],
            "competition": [
                {"name": "Competitor Name", "description": "What they do", "gap": "What this NASA tech offers that they don't"}
            ],
            "revenueModels": ["Revenue model 1", "Revenue model 2"],
            "roadmap": [
                {"step": 1, "title": "Step Title", "description": "What to do"}
            ],
            "costEstimates": {
                "prototyping": "$X - $Y",
                "manufacturing": "$X - $Y",
                "marketing": "$X - $Y",
                "total": "$X - $Y"
            }
        }

        Provide 3-5 business ideas, 3-5 target markets, 2-4 competitors, 2-4 revenue models, and 5-7 roadmap steps.
        Be specific, realistic, and actionable. Focus on practical opportunities for startups and small businesses.
        Return ONLY the JSON, no additional text.
        """
    }

    private func sendRequest(prompt: String, apiKey: String) async throws -> String {
        guard let url = URL(string: apiURL) else {
            throw AIServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw AIServiceError.apiError(message)
            }
            throw AIServiceError.httpError(httpResponse.statusCode)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw AIServiceError.invalidResponse
        }

        return text
    }

    private func parseAnalysisResponse(_ response: String, patentId: String) throws -> BusinessAnalysis {
        // Extract JSON from response (in case there's any surrounding text)
        let jsonString = extractJSON(from: response)

        guard let data = jsonString.data(using: .utf8) else {
            throw AIServiceError.parsingError
        }

        let decoder = JSONDecoder()
        let parsed = try decoder.decode(AnalysisJSON.self, from: data)

        return BusinessAnalysis(
            patentId: patentId,
            businessIdeas: parsed.businessIdeas.map { BusinessIdea(name: $0.name, description: $0.description, potentialScale: $0.potentialScale) },
            targetMarkets: parsed.targetMarkets,
            competition: parsed.competition.map { CompetitorInfo(name: $0.name, description: $0.description, gap: $0.gap) },
            revenueModels: parsed.revenueModels,
            roadmap: parsed.roadmap.enumerated().map { RoadmapStep(step: $0.offset + 1, title: $0.element.title, description: $0.element.description) },
            costEstimates: parsed.costEstimates
        )
    }

    private func extractJSON(from text: String) -> String {
        // Find JSON object boundaries
        guard let startIndex = text.firstIndex(of: "{"),
              let endIndex = text.lastIndex(of: "}") else {
            return text
        }
        return String(text[startIndex...endIndex])
    }

    // MARK: - Find Patents for Problem

    func findPatentsForProblem(_ problem: String, patents: [Patent]) async throws -> ProblemSolution {
        guard let apiKey = KeychainService.shared.getAPIKey(), !apiKey.isEmpty else {
            throw AIServiceError.noAPIKey
        }

        let prompt = buildProblemSolverPrompt(problem: problem, patents: patents)
        let response = try await sendRequest(prompt: prompt, apiKey: apiKey)
        return try parseProblemSolution(response, problem: problem)
    }

    func extractSearchTerms(from problem: String) async throws -> [String] {
        guard let apiKey = KeychainService.shared.getAPIKey(), !apiKey.isEmpty else {
            throw AIServiceError.noAPIKey
        }

        let prompt = """
        Extract 3-5 search keywords from this problem description that would help find relevant NASA patents.
        Focus on technical terms, materials, processes, or phenomena.

        Problem: \(problem)

        Return ONLY a JSON array of strings, nothing else:
        ["keyword1", "keyword2", "keyword3"]
        """

        let response = try await sendRequest(prompt: prompt, apiKey: apiKey)

        // Parse JSON array
        let cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8),
              let keywords = try? JSONDecoder().decode([String].self, from: data) else {
            // Fallback: split problem into words
            return problem.components(separatedBy: .whitespaces)
                .filter { $0.count > 4 }
                .prefix(3)
                .map { String($0) }
        }

        return keywords
    }

    private func buildProblemSolverPrompt(problem: String, patents: [Patent]) -> String {
        let patentList = patents.prefix(15).enumerated().map { index, patent in
            """
            [\(index + 1)] \(patent.title)
            Case: \(patent.caseNumber)
            Category: \(patent.category)
            Description: \(patent.description.prefix(300))...
            """
        }.joined(separator: "\n\n")

        return """
        You are a NASA technology transfer specialist helping entrepreneurs find NASA patents to solve real-world problems.

        USER'S PROBLEM:
        \(problem)

        AVAILABLE NASA PATENTS:
        \(patentList)

        Analyze which patents could help solve this problem. Return your response in this exact JSON format:

        {
            "summary": "Brief explanation of how NASA technology can help with this problem",
            "matches": [
                {
                    "patentIndex": 1,
                    "relevanceScore": 85,
                    "explanation": "How this specific patent addresses the user's problem",
                    "applicationIdea": "Concrete way to apply this technology to their situation"
                }
            ],
            "additionalSuggestions": "Any other advice or alternative approaches"
        }

        Rules:
        - Only include patents with relevanceScore >= 60
        - Sort by relevanceScore descending
        - Maximum 5 matches
        - Be specific about how each technology applies
        - If no patents are relevant, return empty matches array with helpful summary
        - Return ONLY the JSON, no additional text
        """
    }

    private func parseProblemSolution(_ response: String, problem: String) throws -> ProblemSolution {
        let jsonString = extractJSON(from: response)

        guard let data = jsonString.data(using: .utf8) else {
            throw AIServiceError.parsingError
        }

        let parsed = try JSONDecoder().decode(ProblemSolutionJSON.self, from: data)

        return ProblemSolution(
            problem: problem,
            summary: parsed.summary,
            matches: parsed.matches.map {
                PatentMatch(
                    patentIndex: $0.patentIndex - 1, // Convert to 0-based
                    relevanceScore: $0.relevanceScore,
                    explanation: $0.explanation,
                    applicationIdea: $0.applicationIdea
                )
            },
            additionalSuggestions: parsed.additionalSuggestions
        )
    }
}

// MARK: - JSON Parsing Models
private struct AnalysisJSON: Codable {
    let businessIdeas: [BusinessIdeaJSON]
    let targetMarkets: [String]
    let competition: [CompetitionJSON]
    let revenueModels: [String]
    let roadmap: [RoadmapJSON]
    let costEstimates: CostEstimate
}

private struct BusinessIdeaJSON: Codable {
    let name: String
    let description: String
    let potentialScale: String
}

private struct CompetitionJSON: Codable {
    let name: String
    let description: String
    let gap: String
}

private struct RoadmapJSON: Codable {
    let step: Int?
    let title: String
    let description: String
}

private struct ProblemSolutionJSON: Codable {
    let summary: String
    let matches: [PatentMatchJSON]
    let additionalSuggestions: String
}

private struct PatentMatchJSON: Codable {
    let patentIndex: Int
    let relevanceScore: Int
    let explanation: String
    let applicationIdea: String
}

// MARK: - Problem Solution Models

struct ProblemSolution {
    let problem: String
    let summary: String
    let matches: [PatentMatch]
    let additionalSuggestions: String
}

struct PatentMatch {
    let patentIndex: Int
    let relevanceScore: Int
    let explanation: String
    let applicationIdea: String
}

// MARK: - Errors
enum AIServiceError: LocalizedError {
    case noAPIKey
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case parsingError

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "Please add your Claude API key in Settings"
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from AI"
        case .httpError(let code):
            return "API error: \(code)"
        case .apiError(let message):
            return message
        case .parsingError:
            return "Failed to parse AI response"
        }
    }
}
