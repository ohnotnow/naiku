@MainActor
protocol APIKeyStoring {
    func apiKey(for provider: ChatProviderID) throws -> String?
    func saveAPIKey(_ apiKey: String, for provider: ChatProviderID) throws
    func deleteAPIKey(for provider: ChatProviderID) throws
}
