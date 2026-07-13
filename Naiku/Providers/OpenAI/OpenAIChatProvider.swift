import Foundation

struct OpenAIChatProvider: ChatProviding {
    let providerID = ChatProviderID.openAI

    private let session: URLSession
    private let endpoint: URL

    init(
        session: URLSession = .shared,
        endpoint: URL = URL(string: "https://api.openai.com/v1/responses")!
    ) {
        self.session = session
        self.endpoint = endpoint
    }

    func send(_ request: ChatRequest, apiKey: String) async throws -> ChatResponse {
        let credential = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !credential.isEmpty else {
            throw ChatError.missingCredentials(.openAI)
        }
        guard !request.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ChatError.invalidRequest(message: "Choose an OpenAI model in Settings.")
        }

        do {
            var urlRequest = URLRequest(url: endpoint)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization")
            urlRequest.httpBody = try JSONEncoder().encode(
                OpenAIRequest(
                    model: request.model,
                    instructions: request.systemPrompt,
                    input: request.messages.map(OpenAIInputMessage.init),
                    maxOutputTokens: request.maxOutputTokens
                )
            )

            let (data, response) = try await session.data(for: urlRequest)
            try Task.checkCancellation()

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ChatError.server(statusCode: -1, message: nil)
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                let apiError = try? JSONDecoder().decode(OpenAIErrorEnvelope.self, from: data)
                throw ChatErrorMapper.http(
                    statusCode: httpResponse.statusCode,
                    message: apiError?.error.message,
                    retryAfter: httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
                )
            }

            let payload = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            let contentText = payload.output
                .filter { $0.type == "message" }
                .flatMap { $0.content ?? [] }
                .filter { $0.type == "output_text" }
                .compactMap(\.text)
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let text = contentText.isEmpty
                ? payload.outputText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                : contentText

            guard !text.isEmpty else { throw ChatError.emptyResponse }
            return ChatResponse(text: text)
        } catch {
            throw ChatErrorMapper.normalized(error)
        }
    }
}

private struct OpenAIRequest: Encodable {
    let model: String
    let instructions: String
    let input: [OpenAIInputMessage]
    let maxOutputTokens: Int

    enum CodingKeys: String, CodingKey {
        case model
        case instructions
        case input
        case maxOutputTokens = "max_output_tokens"
    }
}

private struct OpenAIInputMessage: Encodable {
    let role: String
    let content: String

    init(_ message: ChatMessage) {
        role = message.role.rawValue
        content = message.text
    }
}

private struct OpenAIResponse: Decodable {
    let output: [OutputItem]
    let outputText: String?

    enum CodingKeys: String, CodingKey {
        case output
        case outputText = "output_text"
    }

    struct OutputItem: Decodable {
        let type: String
        let content: [ContentBlock]?
    }

    struct ContentBlock: Decodable {
        let type: String
        let text: String?
    }
}

private struct OpenAIErrorEnvelope: Decodable {
    let error: APIError

    struct APIError: Decodable {
        let message: String
    }
}
