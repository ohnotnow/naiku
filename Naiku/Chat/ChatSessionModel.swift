import Combine
import Foundation

@MainActor
final class ChatSessionModel: ObservableObject {
    @Published var draft = ""
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var pendingMessage: ChatMessage?
    @Published private(set) var isSending = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var focusRequest = 0

    let settings: SettingsModel

    private var history: ConversationHistory
    private let providers: [ChatProviderID: any ChatProviding]
    private var currentTask: Task<Void, Never>?

    init(
        settings: SettingsModel,
        providers: [ChatProviderID: any ChatProviding],
        maximumMessageCount: Int = 12
    ) {
        self.settings = settings
        self.providers = providers
        history = ConversationHistory(maximumMessageCount: maximumMessageCount)
    }

    var providerSummary: String {
        "\(settings.activeProvider.displayName) · \(settings.model(for: settings.activeProvider))"
    }

    @discardableResult
    func send() -> Task<Void, Never>? {
        guard !isSending else { return nil }

        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        let providerID = settings.activeProvider
        guard let provider = providers[providerID] else {
            errorMessage = "The selected provider is not available."
            return nil
        }

        let apiKey: String
        do {
            guard let storedKey = try settings.apiKey(for: providerID), !storedKey.isEmpty else {
                throw ChatError.missingCredentials(providerID)
            }
            apiKey = storedKey
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Naiku could not read that API key from Keychain."
            return nil
        }

        let userMessage = ChatMessage(role: .user, text: text)
        let request = ChatRequest(
            model: settings.model(for: providerID),
            messages: history.messages + [userMessage]
        )

        pendingMessage = userMessage
        errorMessage = nil
        isSending = true

        let task = Task { [weak self] in
            do {
                let response = try await provider.send(request, apiKey: apiKey)
                try Task.checkCancellation()
                self?.finishSuccess(userMessage: userMessage, response: response)
            } catch is CancellationError {
                self?.finishCancellation()
            } catch {
                self?.finishFailure(error)
            }
        }
        currentTask = task
        return task
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
        pendingMessage = nil
        isSending = false
    }

    func newConversation() {
        cancel()
        history.clear()
        messages = []
        draft = ""
        errorMessage = nil
    }

    func requestInputFocus() {
        focusRequest += 1
    }

    private func finishSuccess(userMessage: ChatMessage, response: ChatResponse) {
        history.append(userMessage)
        history.append(ChatMessage(role: .assistant, text: response.text))
        messages = history.messages
        draft = ""
        pendingMessage = nil
        errorMessage = nil
        isSending = false
        currentTask = nil
    }

    private func finishCancellation() {
        pendingMessage = nil
        isSending = false
        currentTask = nil
    }

    private func finishFailure(_ error: Error) {
        pendingMessage = nil
        isSending = false
        currentTask = nil
        errorMessage = (error as? LocalizedError)?.errorDescription
            ?? "Naiku could not finish that reply. Please try again."
    }
}
