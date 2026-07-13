import Foundation
import XCTest
@testable import Naiku

final class OpenAIChatProviderTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.reset()
        super.tearDown()
    }

    func testSuccessfulRequestUsesResponsesContractAndCollectsOutputText() async throws {
        URLProtocolStub.install { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = Data(#"{"output":[{"type":"reasoning","content":null},{"type":"message","role":"assistant","content":[{"type":"output_text","text":"Moonlight."},{"type":"refusal","refusal":"ignored"}]},{"type":"message","role":"assistant","content":[{"type":"output_text","text":"Purr."}]}]}"#.utf8)
            return (response, data)
        }
        let request = ChatRequest(
            model: "gpt-test-model",
            messages: [
                ChatMessage(role: .user, text: "Hello"),
                ChatMessage(role: .assistant, text: "Hi"),
                ChatMessage(role: .user, text: "Wave"),
            ],
            systemPrompt: "Be a cat.",
            maxOutputTokens: 111
        )

        let result = try await provider().send(request, apiKey: "test-openai-key")

        XCTAssertEqual(result.text, "Moonlight.\nPurr.")
        let captured = try await captureRequest(for: request)
        XCTAssertEqual(captured.httpMethod, "POST")
        XCTAssertEqual(captured.url?.absoluteString, "https://api.openai.com/v1/responses")
        XCTAssertEqual(captured.value(forHTTPHeaderField: "Authorization"), "Bearer test-openai-key")

        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: XCTUnwrap(captured.httpBody)) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "gpt-test-model")
        XCTAssertEqual(json["instructions"] as? String, "Be a cat.")
        XCTAssertEqual(json["max_output_tokens"] as? Int, 111)
        XCTAssertEqual((json["input"] as? [[String: Any]])?.map { $0["role"] as? String }, ["user", "assistant", "user"])
    }

    func testTopLevelOutputTextIsUsedAsSafeFallback() async throws {
        URLProtocolStub.install { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"output":[],"output_text":"Fallback text"}"#.utf8))
        }

        let result = try await provider().send(sampleRequest, apiKey: "test-key")
        XCTAssertEqual(result.text, "Fallback text")
    }

    func testAuthenticationFailureIsNormalized() async {
        await assertError(statusCode: 401, expected: .authentication)
    }

    func testRateLimitIncludesRetryAfter() async {
        await assertError(statusCode: 429, headers: ["Retry-After": "4"], expected: .rateLimited(retryAfter: 4))
    }

    func testAPIErrorPreservesSafeProviderMessage() async {
        await assertError(
            statusCode: 400,
            message: "model is unavailable",
            expected: .invalidRequest(message: "model is unavailable")
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
            _ = try await provider().send(sampleRequest, apiKey: "")
            XCTFail("Expected missing credentials")
        } catch {
            XCTAssertEqual(error as? ChatError, .missingCredentials(.openAI))
        }
    }

    private var sampleRequest: ChatRequest {
        ChatRequest(model: "gpt-test", messages: [ChatMessage(role: .user, text: "Hello")])
    }

    private func provider() -> OpenAIChatProvider {
        OpenAIChatProvider(session: URLProtocolStub.makeSession())
    }

    private func assertError(
        statusCode: Int,
        headers: [String: String] = [:],
        message: String = "provider error",
        expected: ChatError
    ) async {
        URLProtocolStub.install { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: headers)!
            let data = Data(#"{"error":{"message":"\#(message)","type":"test_error","code":"test"}}"#.utf8)
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
        let captured = OpenAILockedRequestBox()
        URLProtocolStub.install { request in
            captured.value = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"output":[{"type":"message","content":[{"type":"output_text","text":"ok"}]}]}"#.utf8))
        }

        _ = try await provider().send(chatRequest, apiKey: "test-openai-key")
        return try XCTUnwrap(captured.value)
    }
}

private final class OpenAILockedRequestBox: @unchecked Sendable {
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
