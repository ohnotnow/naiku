import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let model: SettingsModel

    init(model: SettingsModel) {
        self.model = model
        let contentView = SettingsView(model: model)
        let hostingController = NSHostingController(rootView: contentView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Naiku Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 500, height: 640))
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        window.delegate = self
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("SettingsWindowController does not support storyboards")
    }

    func show() {
        if window?.isVisible != true {
            ensureVisible()
            showWindow(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        if window?.isKeyWindow != true {
            window?.makeKeyAndOrderFront(nil)
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.makeFirstResponder(nil)
        model.clearCredentialDrafts()
        return true
    }

    func windowWillClose(_ notification: Notification) {
        model.clearCredentialDrafts()
    }

    private func ensureVisible() {
        guard let window else { return }
        let bounds = DesktopGeometry.nearestVisibleBounds(
            to: window.frame,
            displays: DesktopGeometry.currentDisplays,
            fallback: NSScreen.main?.visibleFrame ?? .zero
        )
        window.setFrameOrigin(MotionEngine.clamp(origin: window.frame.origin, petSize: window.frame.size, to: bounds))
    }

    @objc
    private func screenParametersDidChange() {
        guard window?.isVisible == true else { return }
        ensureVisible()
    }
}
