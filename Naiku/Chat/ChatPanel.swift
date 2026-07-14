import AppKit

/// A borderless glass panel that can still take keyboard focus for typing.
/// Borderless windows refuse key status by default, which would leave the
/// chat input impossible to type into.
@MainActor
final class ChatPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    /// Borderless windows have no close widget, so AppKit's `performClose`
    /// beeps instead of closing. Run the `windowShouldClose` contract
    /// ourselves so delegates still get their say.
    override func performClose(_ sender: Any?) {
        if delegate?.windowShouldClose?(self) == false {
            return
        }
        close()
    }
}
