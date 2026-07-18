import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Summons the chat panel from anywhere. No default combination —
    /// the user records one in Settings if they want it.
    @MainActor static let openChat = Self("openChat")
}
