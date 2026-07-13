protocol ChatProviding: Sendable {
    var providerID: ChatProviderID { get }

    /// Implementations must honour structured-concurrency cancellation. A
    /// cancelled URLSession request should surface as `CancellationError`.
    func send(_ request: ChatRequest, apiKey: String) async throws -> ChatResponse
}
