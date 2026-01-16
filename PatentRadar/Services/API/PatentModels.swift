import Foundation
import SwiftUI

// MARK: - Patent Model (Basic - from search API)
struct Patent: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let description: String
    let category: String
    let caseNumber: String
    let patentNumber: String?
    let imageURL: String?
    let center: String?
    let trl: String?

    var usptoURL: URL? {
        guard let num = patentNumber else { return nil }
        return URL(string: "https://patents.google.com/patent/US\(num)")
    }

    var categoryIcon: String {
        switch category.lowercased() {
        case let c where c.contains("aeronautic"): return "airplane"
        case let c where c.contains("propulsion"): return "flame"
        case let c where c.contains("material"): return "cube"
        case let c where c.contains("sensor"): return "sensor.tag.radiowaves.forward"
        case let c where c.contains("electronic"): return "cpu"
        case let c where c.contains("software"): return "desktopcomputer"
        case let c where c.contains("robotics"): return "gearshape.2"
        case let c where c.contains("optic"): return "camera"
        case let c where c.contains("communication"): return "antenna.radiowaves.left.and.right"
        case let c where c.contains("environment"): return "leaf"
        case let c where c.contains("health"): return "heart"
        case let c where c.contains("manufacturing"): return "hammer"
        case let c where c.contains("power"): return "bolt"
        case let c where c.contains("information"): return "doc.text"
        default: return "star"
        }
    }
}

// MARK: - Media Item (for unified image/video handling)
enum MediaItem: Identifiable {
    case image(String)
    case video(String)

    var id: String {
        switch self {
        case .image(let url): return "img_\(url)"
        case .video(let url): return "vid_\(url)"
        }
    }

    var isVideo: Bool {
        if case .video = self { return true }
        return false
    }
}

// MARK: - Patent Detail (Rich - from page scraping)
struct PatentDetail: Identifiable {
    let id: String
    let caseNumber: String
    let title: String
    let fullDescription: String
    let benefits: [String]
    let applications: [String]
    let images: [String]
    let videos: [String]
    let patentNumbers: [String]
    let relatedTechnologies: [String]

    var hasRichContent: Bool {
        !benefits.isEmpty || !applications.isEmpty || images.count > 1 || !patentNumbers.isEmpty
    }

    var hasMedia: Bool {
        !images.isEmpty || !videos.isEmpty
    }
}

// MARK: - NASA API Response
// Note: NASA API returns results as arrays of values, not objects
struct NASAPatentResponse: Codable {
    let results: [[JSONValue]]
    let count: Int
    let total: Int
    let perpage: Int
    let page: Int

    func toPatents() -> [Patent] {
        results.compactMap { array -> Patent? in
            guard array.count >= 10 else { return nil }

            // Array positions:
            // 0: id, 1: case number, 2: title, 3: description
            // 4: case number again, 5: category, 6-8: unused
            // 9: center, 10: image URL

            let id = array[0].stringValue ?? UUID().uuidString
            let caseNumber = array[1].stringValue ?? ""
            var title = array[2].stringValue ?? "Untitled"
            var description = array[3].stringValue ?? ""
            let category = array[5].stringValue ?? "General"
            let center = array.count > 9 ? array[9].stringValue : nil
            let imageURL = array.count > 10 ? array[10].stringValue : nil

            // Clean HTML tags from title and description
            title = title
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&#039;", with: "'")
                .replacingOccurrences(of: "&nbsp;", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            description = description
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&#039;", with: "'")
                .replacingOccurrences(of: "&nbsp;", with: " ")
                .replacingOccurrences(of: "\\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return Patent(
                id: id,
                title: title,
                description: description,
                category: category,
                caseNumber: caseNumber,
                patentNumber: nil,
                imageURL: imageURL,
                center: center,
                trl: nil
            )
        }
    }
}

// MARK: - ElasticSearch API Response (used by website)
struct ElasticSearchResult: Codable {
    let id: String
    let source: ElasticSearchSource

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case source = "_source"
    }
}

struct ElasticSearchSource: Codable {
    let title: String?
    let abstract: String?
    let techDesc: String?
    let category: String?
    let clientRecordId: String?
    let center: String?
    let patentNumber: String?
    let trl: String?
    let img1: String?

    enum CodingKeys: String, CodingKey {
        case title
        case abstract
        case techDesc = "tech_desc"
        case category
        case clientRecordId = "client_record_id"
        case center
        case patentNumber = "patent_number"
        case trl
        case img1
    }
}

// Helper to decode mixed JSON array values
enum JSONValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    var stringValue: String? {
        switch self {
        case .string(let s): return s.isEmpty ? nil : s
        case .int(let i): return String(i)
        case .double(let d): return String(d)
        case .bool(let b): return String(b)
        case .null: return nil
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let i = try? container.decode(Int.self) {
            self = .int(i)
        } else if let d = try? container.decode(Double.self) {
            self = .double(d)
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if container.decodeNil() {
            self = .null
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i): try container.encode(i)
        case .double(let d): try container.encode(d)
        case .bool(let b): try container.encode(b)
        case .null: try container.encodeNil()
        }
    }
}

// MARK: - Categories
enum PatentCategory: String, CaseIterable {
    case all = "All"
    case aeronautics = "Aeronautics"
    case communications = "Communications"
    case electronics = "Electronics"
    case environment = "Environment"
    case health = "Health Medicine and Biotechnology"
    case information = "Information Technology and Software"
    case instrumentation = "Instrumentation"
    case manufacturing = "Manufacturing"
    case materials = "Materials and Coatings"
    case mechanical = "Mechanical and Fluid Systems"
    case optics = "Optics"
    case power = "Power Generation and Storage"
    case propulsion = "Propulsion"
    case robotics = "Robotics Automation and Control"
    case sensors = "Sensors"

    var displayName: String {
        switch self {
        case .all: return "All Categories"
        case .health: return "Health & Biotech"
        case .information: return "Software & IT"
        case .materials: return "Materials"
        case .mechanical: return "Mechanical"
        case .robotics: return "Robotics"
        default: return rawValue
        }
    }

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .aeronautics: return "airplane"
        case .communications: return "antenna.radiowaves.left.and.right"
        case .electronics: return "cpu"
        case .environment: return "leaf"
        case .health: return "heart"
        case .information: return "desktopcomputer"
        case .instrumentation: return "gauge"
        case .manufacturing: return "hammer"
        case .materials: return "cube"
        case .mechanical: return "gearshape"
        case .optics: return "camera"
        case .power: return "bolt"
        case .propulsion: return "flame"
        case .robotics: return "gearshape.2"
        case .sensors: return "sensor.tag.radiowaves.forward"
        }
    }

    var shortName: String {
        switch self {
        case .all: return "All"
        case .aeronautics: return "Aero"
        case .communications: return "Comms"
        case .electronics: return "Electronics"
        case .environment: return "Enviro"
        case .health: return "Health"
        case .information: return "Software"
        case .instrumentation: return "Instrum"
        case .manufacturing: return "Mfg"
        case .materials: return "Materials"
        case .mechanical: return "Mech"
        case .optics: return "Optics"
        case .power: return "Power"
        case .propulsion: return "Propulsion"
        case .robotics: return "Robotics"
        case .sensors: return "Sensors"
        }
    }

    var color: Color {
        switch self {
        case .all: return .blue
        case .aeronautics: return .cyan
        case .communications: return .purple
        case .electronics: return .indigo
        case .environment: return .green
        case .health: return .red
        case .information: return .teal
        case .instrumentation: return .orange
        case .manufacturing: return .brown
        case .materials: return .mint
        case .mechanical: return .gray
        case .optics: return .pink
        case .power: return .yellow
        case .propulsion: return Color(.systemOrange)
        case .robotics: return Color(.systemTeal)
        case .sensors: return Color(.systemPurple)
        }
    }

    // API category slugs - matches NASA Technology Transfer API
    var apiSlug: String? {
        switch self {
        case .all: return nil
        case .aeronautics: return "aerospace"
        case .communications: return "communications"
        case .electronics: return "electrical%20and%20electronics"
        case .environment: return "environment"
        case .health: return "health%20medicine%20and%20biotechnology"
        case .information: return "information%20technology%20and%20software"
        case .instrumentation: return "instrumentation"
        case .manufacturing: return "manufacturing"
        case .materials: return "materials%20and%20coatings"
        case .mechanical: return "mechanical%20and%20fluid%20systems"
        case .optics: return "optics"
        case .power: return "power%20generation%20and%20storage"
        case .propulsion: return "propulsion"
        case .robotics: return "robotics%20automation%20and%20control"
        case .sensors: return "sensors"
        }
    }
}

// MARK: - Business Analysis Model
struct BusinessAnalysis: Identifiable, Codable {
    let id: UUID
    let patentId: String
    let businessIdeas: [BusinessIdea]
    let targetMarkets: [String]
    let competition: [CompetitorInfo]
    let revenueModels: [String]
    let roadmap: [RoadmapStep]
    let costEstimates: CostEstimate
    let generatedAt: Date

    init(
        patentId: String,
        businessIdeas: [BusinessIdea],
        targetMarkets: [String],
        competition: [CompetitorInfo],
        revenueModels: [String],
        roadmap: [RoadmapStep],
        costEstimates: CostEstimate
    ) {
        self.id = UUID()
        self.patentId = patentId
        self.businessIdeas = businessIdeas
        self.targetMarkets = targetMarkets
        self.competition = competition
        self.revenueModels = revenueModels
        self.roadmap = roadmap
        self.costEstimates = costEstimates
        self.generatedAt = Date()
    }
}

struct BusinessIdea: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let potentialScale: String // "Small", "Medium", "Large"

    init(name: String, description: String, potentialScale: String) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.potentialScale = potentialScale
    }
}

struct CompetitorInfo: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let gap: String // What NASA tech provides that competitor doesn't

    init(name: String, description: String, gap: String) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.gap = gap
    }
}

struct RoadmapStep: Identifiable, Codable {
    let id: UUID
    let step: Int
    let title: String
    let description: String

    init(step: Int, title: String, description: String) {
        self.id = UUID()
        self.step = step
        self.title = title
        self.description = description
    }
}

struct CostEstimate: Codable {
    let prototyping: String
    let manufacturing: String
    let marketing: String
    let total: String
}
