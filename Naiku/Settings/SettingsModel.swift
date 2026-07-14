import Combine
import Foundation

@MainActor
final class SettingsModel: ObservableObject {
    @Published private(set) var activeProvider: ChatProviderID
    @Published var anthropicModel: String
    @Published var openAIModel: String
    @Published var anthropicKeyDraft = ""
    @Published var openAIKeyDraft = ""
    @Published private(set) var hasAnthropicKey = false
    @Published private(set) var hasOpenAIKey = false
    @Published private(set) var showsOverFullScreenApps: Bool
    @Published private(set) var statusMessage: String?

    private let keyStore: APIKeyStoring
    private let preferences: PreferencesStoring
    private var onProviderChanged: @MainActor () -> Void
    private let onFullScreenVisibilityChanged: @MainActor (Bool) -> Void

    init(
        keyStore: APIKeyStoring,
        preferences: PreferencesStoring,
        onProviderChanged: @escaping @MainActor () -> Void = {},
        onFullScreenVisibilityChanged: @escaping @MainActor (Bool) -> Void = { _ in }
    ) {
        self.keyStore = keyStore
        self.preferences = preferences
        self.onProviderChanged = onProviderChanged
        self.onFullScreenVisibilityChanged = onFullScreenVisibilityChanged
        activeProvider = preferences.activeProvider
        anthropicModel = preferences.model(for: .anthropic)
        openAIModel = preferences.model(for: .openAI)
        showsOverFullScreenApps = preferences.showsOverFullScreenApps
        refreshCredentialStatus()
    }

    func apiKey(for provider: ChatProviderID) throws -> String? {
        try keyStore.apiKey(for: provider)
    }

    func model(for provider: ChatProviderID) -> String {
        switch provider {
        case .anthropic: anthropicModel.trimmingCharacters(in: .whitespacesAndNewlines)
        case .openAI: openAIModel.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    func selectProvider(_ provider: ChatProviderID) {
        guard provider != activeProvider else { return }
        activeProvider = provider
        preferences.activeProvider = provider
        statusMessage = "Started a new \(provider.displayName) conversation."
        onProviderChanged()
    }

    func setProviderChangeHandler(_ handler: @escaping @MainActor () -> Void) {
        onProviderChanged = handler
    }

    func setShowsOverFullScreenApps(_ shows: Bool) {
        guard shows != showsOverFullScreenApps else { return }
        showsOverFullScreenApps = shows
        preferences.showsOverFullScreenApps = shows
        onFullScreenVisibilityChanged(shows)
    }

    /// Persists the model fields as they are edited. Unlike the old
    /// "Save Model Choices" button this never rewrites the published values,
    /// so typing is not disturbed.
    func persistModels() {
        preferences.setModel(anthropicModel, for: .anthropic)
        preferences.setModel(openAIModel, for: .openAI)
    }

    func saveKey(for provider: ChatProviderID) {
        let draft = keyDraft(for: provider).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !draft.isEmpty else {
            statusMessage = "Paste an API key before saving."
            return
        }

        do {
            try keyStore.saveAPIKey(draft, for: provider)
            setKeyDraft("", for: provider)
            setConfigured(true, for: provider)
            statusMessage = "\(provider.displayName) key saved in Keychain."
        } catch {
            statusMessage = "The key could not be saved in Keychain."
        }
    }

    func deleteKey(for provider: ChatProviderID) {
        do {
            try keyStore.deleteAPIKey(for: provider)
            setKeyDraft("", for: provider)
            setConfigured(false, for: provider)
            statusMessage = "\(provider.displayName) key removed."
        } catch {
            statusMessage = "The key could not be removed from Keychain."
        }
    }

    func clearCredentialDrafts() {
        anthropicKeyDraft = ""
        openAIKeyDraft = ""
    }

    private func refreshCredentialStatus() {
        hasAnthropicKey = (try? keyStore.apiKey(for: .anthropic)) != nil
        hasOpenAIKey = (try? keyStore.apiKey(for: .openAI)) != nil
    }

    private func keyDraft(for provider: ChatProviderID) -> String {
        switch provider {
        case .anthropic: anthropicKeyDraft
        case .openAI: openAIKeyDraft
        }
    }

    private func setKeyDraft(_ draft: String, for provider: ChatProviderID) {
        switch provider {
        case .anthropic: anthropicKeyDraft = draft
        case .openAI: openAIKeyDraft = draft
        }
    }

    private func setConfigured(_ configured: Bool, for provider: ChatProviderID) {
        switch provider {
        case .anthropic: hasAnthropicKey = configured
        case .openAI: hasOpenAIKey = configured
        }
    }
}
