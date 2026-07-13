import AppKit
import XCTest
@testable import Naiku

@MainActor
final class StatusMenuControllerTests: XCTestCase {
    func testMenuExposesLifecycleActionsAndTogglesPause() throws {
        var observedPause: Bool?
        var chatCount = 0
        var settingsCount = 0
        var quitCount = 0
        let controller = StatusMenuController(
            onShowChat: { chatCount += 1 },
            onPauseChanged: { observedPause = $0 },
            onShowSettings: { settingsCount += 1 },
            onQuit: { quitCount += 1 }
        )

        XCTAssertEqual(
            controller.menu.items.map(\.title),
            ["Chat with Naiku…", "Pause Naiku", "Settings…", "", "Quit Naiku"]
        )

        controller.menu.performActionForItem(at: 0)
        XCTAssertEqual(chatCount, 1)

        controller.menu.performActionForItem(at: 1)
        XCTAssertTrue(controller.isPaused)
        XCTAssertEqual(observedPause, true)
        XCTAssertEqual(controller.menu.item(at: 1)?.title, "Resume Naiku")

        controller.menu.performActionForItem(at: 1)
        XCTAssertFalse(controller.isPaused)
        XCTAssertEqual(observedPause, false)

        controller.menu.performActionForItem(at: 2)
        controller.menu.performActionForItem(at: 4)
        XCTAssertEqual(settingsCount, 1)
        XCTAssertEqual(quitCount, 1)

        controller.tearDown()
    }

    func testSettingsControllerReusesOneWindow() throws {
        let model = SettingsModel(
            keyStore: InMemoryAPIKeyStore(),
            preferences: InMemoryPreferences()
        )
        let controller = SettingsWindowController(model: model)
        let originalWindow = try XCTUnwrap(controller.window)

        controller.show()
        controller.show()
        model.anthropicKeyDraft = "discard-on-close"

        XCTAssertTrue(originalWindow === controller.window)
        controller.close()
        XCTAssertEqual(model.anthropicKeyDraft, "")
    }
}

@MainActor
private final class InMemoryAPIKeyStore: APIKeyStoring {
    func apiKey(for provider: ChatProviderID) throws -> String? { nil }
    func saveAPIKey(_ apiKey: String, for provider: ChatProviderID) throws {}
    func deleteAPIKey(for provider: ChatProviderID) throws {}
}

@MainActor
private final class InMemoryPreferences: PreferencesStoring {
    var activeProvider = ChatProviderID.anthropic
    private var models: [ChatProviderID: String] = [:]

    func model(for provider: ChatProviderID) -> String {
        models[provider] ?? provider.suggestedModel
    }

    func setModel(_ model: String, for provider: ChatProviderID) {
        models[provider] = model
    }
}
