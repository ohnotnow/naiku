import Darwin
import Foundation

@main
enum LiveProviderSmoke {
    static func main() async {
        let environment = ProcessInfo.processInfo.environment
        let runNegativeChecks = CommandLine.arguments.contains("--negative")
        let openAIKey = nonEmpty(environment["OPENAI_API_KEY"])
        let anthropicKey = nonEmpty(environment["ANTHROPIC_API_KEY"])

        guard openAIKey != nil || anthropicKey != nil else {
            print("No live provider keys are set; nothing to test.")
            exit(2)
        }

        var failed = false

        if let openAIKey {
            let provider = OpenAIChatProvider()
            failed = !(await check(
                providerName: "OpenAI",
                provider: provider,
                model: ChatProviderID.openAI.suggestedModel,
                apiKey: openAIKey
            )) || failed
            if runNegativeChecks {
                failed = !(await checkExpectedFailures(
                    providerName: "OpenAI",
                    provider: provider,
                    validModel: ChatProviderID.openAI.suggestedModel,
                    validAPIKey: openAIKey
                )) || failed
            }
        } else {
            print("OpenAI: skipped (OPENAI_API_KEY is not set)")
        }

        if let anthropicKey {
            let provider = AnthropicChatProvider()
            failed = !(await check(
                providerName: "Anthropic",
                provider: provider,
                model: ChatProviderID.anthropic.suggestedModel,
                apiKey: anthropicKey
            )) || failed
            if runNegativeChecks {
                failed = !(await checkExpectedFailures(
                    providerName: "Anthropic",
                    provider: provider,
                    validModel: ChatProviderID.anthropic.suggestedModel,
                    validAPIKey: anthropicKey
                )) || failed
            }
        } else {
            print("Anthropic: skipped (ANTHROPIC_API_KEY is not set)")
        }

        exit(failed ? 1 : 0)
    }

    private static func check(
        providerName: String,
        provider: some ChatProviding,
        model: String,
        apiKey: String
    ) async -> Bool {
        let request = smokeRequest(model: model)

        do {
            let response = try await provider.send(request, apiKey: apiKey)
            let count = response.text.count
            guard count > 0 else { throw ChatError.emptyResponse }
            print("\(providerName): success (\(count) response characters)")
            return true
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            print("\(providerName): failed (\(message))")
            return false
        }
    }

    private static func checkExpectedFailures(
        providerName: String,
        provider: some ChatProviding,
        validModel: String,
        validAPIKey: String
    ) async -> Bool {
        let authentication = await expectFailure(
            providerName: providerName,
            checkName: "invalid key",
            provider: provider,
            model: validModel,
            apiKey: "naiku-deliberately-invalid-key"
        ) { $0 == .authentication }
        let model = await expectFailure(
            providerName: providerName,
            checkName: "invalid model",
            provider: provider,
            model: "naiku-deliberately-invalid-model",
            apiKey: validAPIKey
        ) {
            if case .invalidRequest = $0 { return true }
            return false
        }
        return authentication && model
    }

    private static func expectFailure(
        providerName: String,
        checkName: String,
        provider: some ChatProviding,
        model: String,
        apiKey: String,
        matches: (ChatError) -> Bool
    ) async -> Bool {
        do {
            _ = try await provider.send(smokeRequest(model: model), apiKey: apiKey)
            print("\(providerName) \(checkName): failed (request unexpectedly succeeded)")
            return false
        } catch let error as ChatError where matches(error) {
            print("\(providerName) \(checkName): mapped correctly")
            return true
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            print("\(providerName) \(checkName): failed (\(message))")
            return false
        }
    }

    private static func smokeRequest(model: String) -> ChatRequest {
        ChatRequest(
            model: model,
            messages: [ChatMessage(role: .user, text: "Reply with one friendly cat sound.")],
            systemPrompt: "This is a connectivity smoke test. Reply briefly and do not use tools.",
            maxOutputTokens: 32
        )
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
