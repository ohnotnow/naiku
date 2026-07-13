import Foundation
import XCTest
@testable import Naiku

final class AnthropicChatProviderTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.reset()
        super.tearDown()
    }

    func testSuccessfulRequestUsesMessagesContractAndCollectsTextBlocks() async throws {
        URLProtocolStub.install { request in
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            let data = Data(#"{"content":[{"type":"text","text":"Purr."},{"type":"tool_use","id":"tool_1","name":"ignored","input":{}},{"type":"text","text":"Hello!"}]}"#.utf8)
            return (response, data)
        }
        let provider = AnthropicChatProvider(session: URLProtocolStub.makeSession())
        let request = ChatRequest(
            model: "claude-test-model",
            messages: [
                ChatMessage(role: .user, text: "Hello"),
                ChatMessage(role: .assistant, text: "Hi"),
                ChatMessage(role: .user, text: "Wave"),
            ],
            systemPrompt: "Be a cat.",
            maxOutputTokens: 123
        )

        let result = try await provider.send(request, apiKey: "test-anthropic-key")

        XCTAssertEqual(result.text, "Purr.\nHello!")
        let captured = try await captureRequest(for: request)
        XCTAssertEqual(captured.httpMethod, "POST")
        XCTAssertEqual(captured.url?.absoluteString, "https://api.anthropic.com/v1/messages")
        XCTAssertEqual(captured.value(forHTTPHeaderField: "x-api-key"), "test-anthropic-key")
        XCTAssertEqual(captured.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")

        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: XCTUnwrap(captured.httpBody)) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "claude-test-model")
        XCTAssertEqual(json["max_tokens"] as? Int, 123)
        XCTAssertEqual(json["system"] as? String, "Be a cat.")
        XCTAssertEqual((json["messages"] as? [[String: Any]])?.map { $0["role"] as? String }, ["user", "assistant", "user"])
    }

    func testAuthenticationFailureIsNormalized() async {
        await assertError(statusCode: 401, expected: .authentication)
    }

    func testRateLimitIncludesRetryAfter() async {
        await assertError(statusCode: 429, headers: ["Retry-After": "3"], expected: .rateLimited(retryAfter: 3))
    }

    func testAPIErrorPreservesSafeProviderMessage() async {
        await assertError(
            statusCode: 400,
            message: "model is not available",
            expected: .invalidRequest(message: "model is not available")
        )
    }

    func testMalformedSuccessIsDecodingError() async {
        URLProtocolStub.install { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("not-json".utf8))
        }

        do {
            _ = try await provider().send(sampleRequest, apiKey: "test-key")
            XCTFail("Expected decoding error")
        } catch {
            XCTAssertEqual(error as? ChatError, .decoding)
        }
    }

    func testMissingCredentialFailsBeforeNetworking() async {
        do {
            _ = try await provider().send(sampleRequest, apiKey: "  ")
            XCTFail("Expected missing credentials")
        } catch {
            XCTAssertEqual(error as? ChatError, .missingCredentials(.anthropic))
        }
    }

    private var sampleRequest: ChatRequest {
        ChatRequest(model: "claude-test", messages: [ChatMessage(role: .user, text: "Hello")])
    }

    private func provider() -> AnthropicChatProvider {
        AnthropicChatProvider(session: URLProtocolStub.makeSession())
    }

    private func assertError(
        statusCode: Int,
        headers: [String: String] = [:],
        message: String = "provider error",
        expected: ChatError
    ) async {
        URLProtocolStub.install { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: headers)!
            let data = Data(#"{"type":"error","error":{"type":"test_error","message":"\#(message)"}}"#.utf8)
            return (response, data)
        }

        do {
            _ = try await provider().send(sampleRequest, apiKey: "test-key")
            XCTFail("Expected \(expected)")
        } catch {
            XCTAssertEqual(error as? ChatError, expected)
        }
    }

    private func captureRequest(for chatRequest: ChatRequest) async throws -> URLRequest {
        let captured = LockedRequestBox()
        URLProtocolStub.install { request in
            captured.value = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"content":[{"type":"text","text":"ok"}]}"#.utf8))
        }

        _ = try await provider().send(chatRequest, apiKey: "test-anthropic-key")
        return try XCTUnwrap(captured.value)
    }
}

private final class LockedRequestBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue: URLRequest?

    var value: URLRequest? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedValue
        }
        set {
            lock.lock()
            storedValue = newValue
            lock.unlock()
        }
    }
}
