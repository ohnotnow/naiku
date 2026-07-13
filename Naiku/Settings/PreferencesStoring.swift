@MainActor
protocol PreferencesStoring: AnyObject {
    var activeProvider: ChatProviderID { get set }
    func model(for provider: ChatProviderID) -> String
    func setModel(_ model: String, for provider: ChatProviderID)
}
