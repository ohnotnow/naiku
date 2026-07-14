import Foundation

@MainActor
final class AppPreferences: PreferencesStoring {
    private enum Key {
        static let activeProvider = "activeProvider"
        static let anthropicModel = "anthropicModel"
        static let openAIModel = "openAIModel"
        static let showsOverFullScreenApps = "showsOverFullScreenApps"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var activeProvider: ChatProviderID {
        get {
            defaults.string(forKey: Key.activeProvider)
                .flatMap(ChatProviderID.init(rawValue:)) ?? .anthropic
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.activeProvider)
        }
    }

    var showsOverFullScreenApps: Bool {
        get { defaults.bool(forKey: Key.showsOverFullScreenApps) }
        set { defaults.set(newValue, forKey: Key.showsOverFullScreenApps) }
    }

    func model(for provider: ChatProviderID) -> String {
        let stored = defaults.string(forKey: modelKey(for: provider))?.trimmingCharacters(in: .whitespacesAndNewlines)
        return stored?.isEmpty == false ? stored! : provider.suggestedModel
    }

    func setModel(_ model: String, for provider: ChatProviderID) {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            defaults.removeObject(forKey: modelKey(for: provider))
        } else {
            defaults.set(trimmed, forKey: modelKey(for: provider))
        }
    }

    private func modelKey(for provider: ChatProviderID) -> String {
        switch provider {
        case .anthropic: Key.anthropicModel
        case .openAI: Key.openAIModel
        }
    }
}
