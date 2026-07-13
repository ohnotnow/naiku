struct ConversationHistory: Equatable, Sendable {
    let maximumMessageCount: Int
    private(set) var messages: [ChatMessage] = []

    init(maximumMessageCount: Int = 12) {
        self.maximumMessageCount = max(1, maximumMessageCount)
    }

    mutating func append(_ message: ChatMessage) {
        messages.append(message)
        if messages.count > maximumMessageCount {
            messages.removeFirst(messages.count - maximumMessageCount)
        }
    }

    mutating func clear() {
        messages.removeAll(keepingCapacity: true)
    }
}
