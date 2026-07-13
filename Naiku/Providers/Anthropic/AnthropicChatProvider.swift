import Foundation

struct AnthropicChatProvider: ChatProviding {
    let providerID = ChatProviderID.anthropic

    private let session: URLSession
    private let endpoint: URL

    init(
        session: URLSession = .shared,
        endpoint: URL = URL(string: "https://api.anthropic.com/v1/messages")!
    ) {
        self.session = session
        self.endpoint = endpoint
    }

    func send(_ request: ChatRequest, apiKey: String) async throws -> ChatResponse {
        let credential = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !credential.isEmpty else {
            throw ChatError.missingCredentials(.anthropic)
        }
        guard !request.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ChatError.invalidRequest(message: "Choose an Anthropic model in Settings.")
        }

        do {
            var urlRequest = URLRequest(url: endpoint)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.setValue(credential, forHTTPHeaderField: "x-api-key")
            urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            urlRequest.httpBody = try JSONEncoder().encode(
                AnthropicRequest(
                    model: request.model,
                    maxTokens: request.maxOutputTokens,
                    system: request.systemPrompt,
                    messages: request.messages.map(AnthropicMessage.init)
                )
            )

            let (data, response) = try await session.data(for: urlRequest)
            try Task.checkCancellation()

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ChatError.server(statusCode: -1, message: nil)
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                let apiError = try? JSONDecoder().decode(AnthropicErrorEnvelope.self, from: data)
                throw ChatErrorMapper.http(
                    statusCode: httpResponse.statusCode,
                    message: apiError?.error.message,
                    retryAfter: httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
                )
            }

            let payload = try JSONDecoder().decode(AnthropicResponse.self, from: data)
            let text = payload.content
                .filter { $0.type == "text" }
                .compactMap(\.text)
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !text.isEmpty else { throw ChatError.emptyResponse }
            return ChatResponse(text: text)
        } catch {
            throw ChatErrorMapper.normalized(error)
        }
    }
}

private struct AnthropicRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String
    let messages: [AnthropicMessage]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
    }
}

private struct AnthropicMessage: Encodable {
    let role: String
    let content: String

    init(_ message: ChatMessage) {
        role = message.role.rawValue
        content = message.text
    }
}

private struct AnthropicResponse: Decodable {
    let content: [ContentBlock]

    struct ContentBlock: Decodable {
        let type: String
        let text: String?
    }
}

private struct AnthropicErrorEnvelope: Decodable {
    let error: APIError

    struct APIError: Decodable {
        let message: String
    }
}
