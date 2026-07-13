import Foundation
import XCTest
@testable import Naiku

final class ChatDomainTests: XCTestCase {
    func testProviderDefaultsRemainEditableValuesRatherThanTypes() {
        XCTAssertEqual(ChatProviderID.anthropic.suggestedModel, "claude-haiku-4-5")
        XCTAssertEqual(ChatProviderID.openAI.suggestedModel, "gpt-5.6-luna")

        let custom = ChatRequest(model: "another-model", messages: [])
        XCTAssertEqual(custom.model, "another-model")
    }

    func testHistoryDropsOldestMessagesAtItsBound() {
        var history = ConversationHistory(maximumMessageCount: 3)
        let messages = (1...5).map { ChatMessage(role: .user, text: "message \($0)") }

        messages.forEach { history.append($0) }

        XCTAssertEqual(history.messages.map(\.text), ["message 3", "message 4", "message 5"])
        history.clear()
        XCTAssertTrue(history.messages.isEmpty)
    }

    func testHTTPErrorNormalization() {
        XCTAssertEqual(ChatErrorMapper.http(statusCode: 401, message: nil), .authentication)
        XCTAssertEqual(ChatErrorMapper.http(statusCode: 403, message: nil), .authentication)
        XCTAssertEqual(
            ChatErrorMapper.http(statusCode: 429, message: nil, retryAfter: 2.5),
            .rateLimited(retryAfter: 2.5)
        )
        XCTAssertEqual(
            ChatErrorMapper.http(statusCode: 400, message: "unknown model"),
            .invalidRequest(message: "unknown model")
        )
        XCTAssertEqual(
            ChatErrorMapper.http(statusCode: 503, message: "unavailable"),
            .server(statusCode: 503, message: "unavailable")
        )
    }

    func testTransportErrorsPreserveCancellationAndNormalizeConnectivity() {
        XCTAssertTrue(ChatErrorMapper.normalized(CancellationError()) is CancellationError)
        XCTAssertTrue(ChatErrorMapper.normalized(URLError(.cancelled)) is CancellationError)
        XCTAssertEqual(ChatErrorMapper.normalized(URLError(.notConnectedToInternet)) as? ChatError, .connectivity)
    }

    func testDomainTypesCrossATaskBoundary() async throws {
        let provider = CancellingFakeProvider()
        let task = Task {
            try await provider.send(ChatRequest(model: "test", messages: []), apiKey: "unused")
        }

        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }
}

private struct CancellingFakeProvider: ChatProviding {
    let providerID = ChatProviderID.anthropic

    func send(_ request: ChatRequest, apiKey: String) async throws -> ChatResponse {
        try Task.checkCancellation()
        return ChatResponse(text: "unexpected")
    }
}
