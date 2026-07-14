import AppKit
import Foundation
import XCTest
@testable import Naiku

@MainActor
final class ChatSessionTests: XCTestCase {
    func testSuccessfulTurnAppearsInTranscriptAndClearsDraft() async throws {
        let context = makeContext { _ in ChatResponse(text: "A tiny reply") }
        context.session.draft = "Hello cat"

        let task = try XCTUnwrap(context.session.send())
        await task.value

        XCTAssertEqual(context.session.messages.map(\.role), [.user, .assistant])
        XCTAssertEqual(context.session.messages.map(\.text), ["Hello cat", "A tiny reply"])
        XCTAssertEqual(context.session.draft, "")
        XCTAssertFalse(context.session.isSending)
        XCTAssertNil(context.session.errorMessage)
    }

    func testDuplicateSubmissionIsRejectedWhileSending() async throws {
        let context = makeContext { _ in
            try await Task.sleep(for: .milliseconds(80))
            return ChatResponse(text: "Done")
        }
        context.session.draft = "Only once"

        let firstTask = try XCTUnwrap(context.session.send())
        XCTAssertNil(context.session.send())
        await firstTask.value

        XCTAssertEqual(context.session.messages.filter { $0.role == .user }.count, 1)
    }

    func testFailureKeepsDraftForRetryAndDoesNotCommitPendingTurn() async throws {
        let context = makeContext { _ in throw ChatError.authentication }
        context.session.draft = "Please retry me"

        let task = try XCTUnwrap(context.session.send())
        await task.value

        XCTAssertEqual(context.session.draft, "Please retry me")
        XCTAssertTrue(context.session.messages.isEmpty)
        XCTAssertNil(context.session.pendingMessage)
        XCTAssertEqual(context.session.errorMessage, ChatError.authentication.errorDescription)
    }

    func testCancellationKeepsDraftAndClearsLoadingState() async throws {
        let context = makeContext { _ in
            try await Task.sleep(for: .seconds(10))
            return ChatResponse(text: "Too late")
        }
        context.session.draft = "Wait"

        let task = try XCTUnwrap(context.session.send())
        context.session.cancel()
        await task.value

        XCTAssertEqual(context.session.draft, "Wait")
        XCTAssertFalse(context.session.isSending)
        XCTAssertTrue(context.session.messages.isEmpty)
        XCTAssertNil(context.session.errorMessage)
    }

    func testHistoryIsBoundedAndProviderChangeStartsFresh() async throws {
        let context = makeContext(maximumMessageCount: 2) { request in
            ChatResponse(text: "Reply to \(request.messages.last?.text ?? "")")
        }
        context.settings.setProviderChangeHandler { [weak session = context.session] in
            session?.newConversation()
        }

        for prompt in ["One", "Two", "Three"] {
            context.session.draft = prompt
            let task = try XCTUnwrap(context.session.send())
            await task.value
        }

        XCTAssertEqual(context.session.messages.map(\.text), ["Three", "Reply to Three"])

        context.settings.selectProvider(.openAI)
        XCTAssertTrue(context.session.messages.isEmpty)
        XCTAssertEqual(context.settings.activeProvider, .openAI)
    }

    func testChatPanelReusesOneWindowAndRequestsFocus() throws {
        let context = makeContext { _ in ChatResponse(text: "unused") }
        var closeCount = 0
        let controller = ChatPanelController(
            session: context.session,
            onOpenSettings: {},
            onClose: { closeCount += 1 }
        )
        let originalWindow = try XCTUnwrap(controller.window)
        let initialFocusRequest = context.session.focusRequest

        controller.show(near: CGRect(x: 200, y: 200, width: 72, height: 72))
        controller.show(near: CGRect(x: 220, y: 220, width: 72, height: 72))

        XCTAssertTrue(originalWindow === controller.window)
        XCTAssertFalse(try XCTUnwrap(controller.window as? NSPanel).hidesOnDeactivate)
        XCTAssertEqual(context.session.focusRequest, initialFocusRequest + 2)

        controller.close()
        XCTAssertEqual(closeCount, 1)
    }

    func testCloseButtonEndsPetInteractionExactlyOnce() throws {
        let context = makeContext { _ in ChatResponse(text: "unused") }
        let pet = PetWindowController()
        let controller = ChatPanelController(
            session: context.session,
            onOpenSettings: {},
            onClose: { pet.endInteraction() }
        )

        pet.show()
        pet.beginInteraction()
        controller.show(near: pet.window?.frame)

        XCTAssertTrue(pet.isInteractionActive)
        XCTAssertTrue(pet.isEffectivelyPaused)

        try XCTUnwrap(controller.window).performClose(nil)

        XCTAssertFalse(pet.isInteractionActive)
        XCTAssertFalse(pet.isEffectivelyPaused)

        controller.close()
        XCTAssertFalse(pet.isInteractionActive)
        pet.tearDown()
    }

    private func makeContext(
        maximumMessageCount: Int = 12,
        handler: @escaping @Sendable (ChatRequest) async throws -> ChatResponse
    ) -> ChatTestContext {
        let keyStore = ChatMemoryKeyStore()
        keyStore.values = [.anthropic: "test-key", .openAI: "test-key"]
        let preferences = ChatMemoryPreferences()
        let settings = SettingsModel(keyStore: keyStore, preferences: preferences)
        let session = ChatSessionModel(
            settings: settings,
            providers: [
                .anthropic: StubChatProvider(providerID: .anthropic, handler: handler),
                .openAI: StubChatProvider(providerID: .openAI, handler: handler),
            ],
            maximumMessageCount: maximumMessageCount
        )
        return ChatTestContext(settings: settings, session: session)
    }
}

@MainActor
private struct ChatTestContext {
    let settings: SettingsModel
    let session: ChatSessionModel
}

private struct StubChatProvider: ChatProviding {
    let providerID: ChatProviderID
    let handler: @Sendable (ChatRequest) async throws -> ChatResponse

    func send(_ request: ChatRequest, apiKey: String) async throws -> ChatResponse {
        try await handler(request)
    }
}

@MainActor
private final class ChatMemoryKeyStore: APIKeyStoring {
    var values: [ChatProviderID: String] = [:]

    func apiKey(for provider: ChatProviderID) throws -> String? { values[provider] }
    func saveAPIKey(_ apiKey: String, for provider: ChatProviderID) throws { values[provider] = apiKey }
    func deleteAPIKey(for provider: ChatProviderID) throws { values.removeValue(forKey: provider) }
}

@MainActor
private final class ChatMemoryPreferences: PreferencesStoring {
    var activeProvider = ChatProviderID.anthropic
    var showsOverFullScreenApps = false
    private var models: [ChatProviderID: String] = [:]

    func model(for provider: ChatProviderID) -> String {
        models[provider] ?? provider.suggestedModel
    }

    func setModel(_ model: String, for provider: ChatProviderID) {
        models[provider] = model
    }
}
