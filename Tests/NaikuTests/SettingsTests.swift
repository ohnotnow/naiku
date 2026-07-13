import Foundation
import Security
import XCTest
@testable import Naiku

@MainActor
final class KeychainAPIKeyStoreTests: XCTestCase {
    func testKeyCanBeSavedReplacedReadAndDeleted() throws {
        let store = KeychainAPIKeyStore(service: "dev.naiku.tests.\(UUID().uuidString)")
        defer { try? store.deleteAPIKey(for: .anthropic) }

        XCTAssertNil(try store.apiKey(for: .anthropic))
        try store.saveAPIKey("first-test-value", for: .anthropic)
        XCTAssertEqual(try store.apiKey(for: .anthropic), "first-test-value")

        try store.saveAPIKey("replacement-test-value", for: .anthropic)
        XCTAssertEqual(try store.apiKey(for: .anthropic), "replacement-test-value")

        try store.deleteAPIKey(for: .anthropic)
        XCTAssertNil(try store.apiKey(for: .anthropic))
    }

    func testProvidersUseIndependentKeychainAccounts() throws {
        let store = KeychainAPIKeyStore(service: "dev.naiku.tests.\(UUID().uuidString)")
        defer {
            try? store.deleteAPIKey(for: .anthropic)
            try? store.deleteAPIKey(for: .openAI)
        }

        try store.saveAPIKey("anthropic-test-value", for: .anthropic)
        try store.saveAPIKey("openai-test-value", for: .openAI)

        XCTAssertEqual(try store.apiKey(for: .anthropic), "anthropic-test-value")
        XCTAssertEqual(try store.apiKey(for: .openAI), "openai-test-value")
    }

    func testKeysAreOnlyAccessibleWhileTheMacIsUnlocked() throws {
        let service = "dev.naiku.tests.\(UUID().uuidString)"
        let store = KeychainAPIKeyStore(service: service)
        defer { try? store.deleteAPIKey(for: .anthropic) }

        try store.saveAPIKey("test-value", for: .anthropic)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: ChatProviderID.anthropic.rawValue,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        XCTAssertEqual(SecItemCopyMatching(query as CFDictionary, &item), errSecSuccess)
    }
}

@MainActor
final class SettingsModelTests: XCTestCase {
    func testDefaultsAndModelChoicesPersistWithoutCredentials() throws {
        let suiteName = "dev.naiku.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = AppPreferences(defaults: defaults)

        XCTAssertEqual(preferences.activeProvider, .anthropic)
        XCTAssertEqual(preferences.model(for: .anthropic), "claude-haiku-4-5")

        preferences.activeProvider = .openAI
        preferences.setModel("  custom-luna  ", for: .openAI)

        let reloaded = AppPreferences(defaults: defaults)
        XCTAssertEqual(reloaded.activeProvider, .openAI)
        XCTAssertEqual(reloaded.model(for: .openAI), "custom-luna")
        XCTAssertNil(defaults.string(forKey: "apiKey"))
    }

    func testModelSavesKeysWithoutKeepingThemInDraftFields() {
        let keyStore = SettingsMemoryKeyStore()
        let preferences = SettingsMemoryPreferences()
        let model = SettingsModel(keyStore: keyStore, preferences: preferences)

        model.anthropicKeyDraft = "secret-test-value"
        model.saveKey(for: .anthropic)

        XCTAssertEqual(keyStore.values[.anthropic], "secret-test-value")
        XCTAssertEqual(model.anthropicKeyDraft, "")
        XCTAssertTrue(model.hasAnthropicKey)

        model.deleteKey(for: .anthropic)
        XCTAssertNil(keyStore.values[.anthropic])
        XCTAssertFalse(model.hasAnthropicKey)
    }

    func testProviderSwitchPersistsAndSignalsConversationReset() {
        let keyStore = SettingsMemoryKeyStore()
        let preferences = SettingsMemoryPreferences()
        var resetCount = 0
        let model = SettingsModel(
            keyStore: keyStore,
            preferences: preferences,
            onProviderChanged: { resetCount += 1 }
        )

        model.selectProvider(.openAI)

        XCTAssertEqual(model.activeProvider, .openAI)
        XCTAssertEqual(preferences.activeProvider, .openAI)
        XCTAssertEqual(resetCount, 1)
        XCTAssertNotNil(model.statusMessage)
    }

    func testCredentialDraftsCanBeDiscardedWithoutChangingStoredKeys() {
        let keyStore = SettingsMemoryKeyStore()
        let model = SettingsModel(keyStore: keyStore, preferences: SettingsMemoryPreferences())
        model.anthropicKeyDraft = "unsaved-anthropic"
        model.openAIKeyDraft = "unsaved-openai"

        model.clearCredentialDrafts()

        XCTAssertEqual(model.anthropicKeyDraft, "")
        XCTAssertEqual(model.openAIKeyDraft, "")
        XCTAssertTrue(keyStore.values.isEmpty)
    }
}

@MainActor
private final class SettingsMemoryKeyStore: APIKeyStoring {
    var values: [ChatProviderID: String] = [:]

    func apiKey(for provider: ChatProviderID) throws -> String? { values[provider] }
    func saveAPIKey(_ apiKey: String, for provider: ChatProviderID) throws { values[provider] = apiKey }
    func deleteAPIKey(for provider: ChatProviderID) throws { values.removeValue(forKey: provider) }
}

@MainActor
private final class SettingsMemoryPreferences: PreferencesStoring {
    var activeProvider = ChatProviderID.anthropic
    var models: [ChatProviderID: String] = [:]

    func model(for provider: ChatProviderID) -> String {
        models[provider] ?? provider.suggestedModel
    }

    func setModel(_ model: String, for provider: ChatProviderID) {
        models[provider] = model
    }
}
