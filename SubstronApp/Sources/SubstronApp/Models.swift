import Foundation

public struct SkillModel: Identifiable, Codable, Hashable {
    public let id: String
    public let name: String
    public let category: String
    public let description: String
    public let score: Double?
    public let full_path: String?
}

public struct TelemetryModel: Codable {
    public let ram_used_gb: Double
    public let ram_total_gb: Double
    public let chip: String
    public let status: String
}

public struct StatusResponse: Codable {
    public let engine: String
    public let status: String
    public let telemetry: TelemetryModel
    public let total_skills: Int
    public let default_model: String
}

public struct SkillsSearchResponse: Codable {
    public let query: String
    public let latency_ms: Double
    public let count: Int
    public let skills: [SkillModel]
}

public enum MessageRole {
    case user
    case assistant
}

public struct ToolActionItem: Identifiable, Hashable {
    public let id = UUID()
    public let tool: String
    public let details: String
    public let status: String
}

public struct ChatMessage: Identifiable {
    public let id = UUID()
    public let role: MessageRole
    public var content: String
    public var thoughts: [String] = []
    public var toolActions: [ToolActionItem] = []
    public var activeSkillName: String?
    public var activeSkillCategory: String?
    public var timestamp: Date = Date()
    public var isStreaming: Bool = false
}
