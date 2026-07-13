import AppKit

/// A click-capable panel that never takes focus away from the user's current app.
@MainActor
final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
