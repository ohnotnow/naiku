import Foundation
import XCTest
@testable import Naiku

final class ProviderContractTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.reset()
        super.tearDown()
    }

    func testBothProvidersNormalizeTransportFailures() async {
        for provider in providers() {
            URLProtocolStub.install { _ in throw URLError(.notConnectedToInternet) }

            do {
                _ = try await provider.send(sampleRequest(for: provider), apiKey: "fixture-key")
                XCTFail("Expected connectivity failure from \(provider.providerID)")
            } catch {
                XCTAssertEqual(error as? ChatError, .connectivity)
            }
        }
    }

    func testBothProvidersPreserveURLCancellation() async {
        for provider in providers() {
            URLProtocolStub.install { _ in throw URLError(.cancelled) }

            do {
                _ = try await provider.send(sampleRequest(for: provider), apiKey: "fixture-key")
                XCTFail("Expected cancellation from \(provider.providerID)")
            } catch {
                XCTAssertTrue(error is CancellationError)
            }
        }
    }

    private func providers() -> [any ChatProviding] {
        let session = URLProtocolStub.makeSession()
        return [
            AnthropicChatProvider(session: session),
            OpenAIChatProvider(session: session),
        ]
    }

    private func sampleRequest(for provider: any ChatProviding) -> ChatRequest {
        ChatRequest(
            model: provider.providerID.suggestedModel,
            messages: [ChatMessage(role: .user, text: "Hello from a test fixture")]
        )
    }
}
