enum ChatProviderID: String, CaseIterable, Codable, Identifiable, Sendable {
    case anthropic
    case openAI

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .anthropic: "Anthropic"
        case .openAI: "OpenAI"
        }
    }

    var suggestedModel: String {
        switch self {
        case .anthropic: "claude-haiku-4-5"
        case .openAI: "gpt-5.6-luna"
        }
    }
}
