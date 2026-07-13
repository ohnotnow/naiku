import AppKit
import SwiftUI

@MainActor
final class ChatPanelController: NSWindowController, NSWindowDelegate {
    private let session: ChatSessionModel
    private let onClose: @MainActor () -> Void
    private var hasFinishedPresentation = true

    init(
        session: ChatSessionModel,
        onOpenSettings: @escaping @MainActor () -> Void,
        onClose: @escaping @MainActor () -> Void
    ) {
        self.session = session
        self.onClose = onClose

        let hostingController = NSHostingController(
            rootView: ChatPanelView(session: session, onOpenSettings: onOpenSettings)
        )
        let panel = NSPanel(contentViewController: hostingController)
        panel.title = "Chat with Naiku"
        panel.styleMask = [.titled, .closable, .resizable, .utilityWindow]
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.setContentSize(NSSize(width: 430, height: 500))
        panel.minSize = NSSize(width: 400, height: 420)

        super.init(window: panel)
        panel.delegate = self
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("ChatPanelController does not support storyboards")
    }

    func show(near petFrame: CGRect?) {
        if window?.isVisible != true {
            hasFinishedPresentation = false
            if let petFrame {
                positionWindow(near: petFrame)
            } else {
                window?.center()
            }
            showWindow(nil)
        }

        NSApp.activate(ignoringOtherApps: true)
        if window?.isKeyWindow != true {
            window?.makeKeyAndOrderFront(nil)
        }
        session.requestInputFocus()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        finishPresentation()
        return true
    }

    func windowWillClose(_ notification: Notification) {
        finishPresentation()
    }

    func tearDown() {
        NotificationCenter.default.removeObserver(self)
        finishPresentation()
        close()
    }

    private func finishPresentation() {
        guard !hasFinishedPresentation else { return }
        hasFinishedPresentation = true
        session.cancel()
        onClose()
    }

    private func positionWindow(near petFrame: CGRect) {
        guard let window else { return }

        let anchor = CGPoint(x: petFrame.midX, y: petFrame.midY)
        let visibleFrame = DesktopGeometry.visibleBounds(containing: anchor)
        let size = window.frame.size

        var origin = CGPoint(x: petFrame.maxX + 12, y: petFrame.midY - size.height / 2)
        if origin.x + size.width > visibleFrame.maxX {
            origin.x = petFrame.minX - size.width - 12
        }
        origin = MotionEngine.clamp(origin: origin, petSize: size, to: visibleFrame)
        window.setFrameOrigin(origin)
    }

    @objc
    private func screenParametersDidChange() {
        guard window?.isVisible == true, let window else { return }
        let bounds = DesktopGeometry.nearestVisibleBounds(
            to: window.frame,
            displays: DesktopGeometry.currentDisplays,
            fallback: NSScreen.main?.visibleFrame ?? .zero
        )
        window.setFrameOrigin(MotionEngine.clamp(origin: window.frame.origin, petSize: window.frame.size, to: bounds))
    }
}
