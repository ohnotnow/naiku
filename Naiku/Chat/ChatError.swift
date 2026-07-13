import Foundation

enum ChatError: Error, Equatable, Sendable {
    case missingCredentials(ChatProviderID)
    case authentication
    case rateLimited(retryAfter: TimeInterval?)
    case invalidRequest(message: String?)
    case connectivity
    case decoding
    case server(statusCode: Int, message: String?)
    case emptyResponse
}

extension ChatError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .missingCredentials(let provider):
            "Add your \(provider.displayName) API key in Settings."
        case .authentication:
            "That API key was not accepted. Check it in Settings."
        case .rateLimited(let retryAfter):
            if let retryAfter {
                "The provider is busy. Try again in about \(Int(retryAfter.rounded(.up))) seconds."
            } else {
                "The provider is busy. Please try again shortly."
            }
        case .invalidRequest(let message):
            message ?? "The provider rejected this request or model. Check the model in Settings."
        case .connectivity:
            "Naiku could not reach the provider. Check your connection and try again."
        case .decoding:
            "The provider returned a response Naiku could not understand."
        case .server(_, let message):
            message ?? "The provider had a problem. Please try again."
        case .emptyResponse:
            "The provider returned no text. Please try again."
        }
    }
}

enum ChatErrorMapper {
    static func http(statusCode: Int, message: String?, retryAfter: TimeInterval? = nil) -> ChatError {
        switch statusCode {
        case 400, 404, 422:
            .invalidRequest(message: message)
        case 401, 403:
            .authentication
        case 429:
            .rateLimited(retryAfter: retryAfter)
        default:
            .server(statusCode: statusCode, message: message)
        }
    }

    static func normalized(_ error: Error) -> Error {
        if error is CancellationError {
            return CancellationError()
        }
        if let urlError = error as? URLError {
            if urlError.code == .cancelled {
                return CancellationError()
            }
            return ChatError.connectivity
        }
        if error is DecodingError {
            return ChatError.decoding
        }
        if let chatError = error as? ChatError {
            return chatError
        }
        return ChatError.server(statusCode: -1, message: nil)
    }
}
