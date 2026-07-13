struct ChatRequest: Equatable, Sendable {
    let model: String
    let messages: [ChatMessage]
    let systemPrompt: String
    let maxOutputTokens: Int

    init(
        model: String,
        messages: [ChatMessage],
        systemPrompt: String = ChatDefaults.systemPrompt,
        maxOutputTokens: Int = ChatDefaults.maxOutputTokens
    ) {
        self.model = model
        self.messages = messages
        self.systemPrompt = systemPrompt
        self.maxOutputTokens = maxOutputTokens
    }
}

struct ChatResponse: Equatable, Sendable {
    let text: String
}

enum ChatDefaults {
    static let maxOutputTokens = 256
    static let systemPrompt = """
        You are Naiku, a tiny desktop cat. Be warm, curious, and playful. \
        Keep replies concise unless the user asks for detail. Never pretend you can see the desktop.
        """
}
