import AppKit

@MainActor
final class StatusMenuController: NSObject {
    private let statusBar: NSStatusBar
    private let onPauseChanged: @MainActor (Bool) -> Void
    private let onShowSettings: @MainActor () -> Void
    private let onQuit: @MainActor () -> Void

    private(set) var statusItem: NSStatusItem
    private(set) var menu: NSMenu
    private(set) var isPaused = false

    private lazy var pauseMenuItem = NSMenuItem(
        title: "Pause Naiku",
        action: #selector(togglePause),
        keyEquivalent: "p"
    )

    init(
        statusBar: NSStatusBar = .system,
        onPauseChanged: @escaping @MainActor (Bool) -> Void,
        onShowSettings: @escaping @MainActor () -> Void,
        onQuit: @escaping @MainActor () -> Void
    ) {
        self.statusBar = statusBar
        self.onPauseChanged = onPauseChanged
        self.onShowSettings = onShowSettings
        self.onQuit = onQuit
        statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        menu = NSMenu(title: AppIdentity.displayName)
        super.init()

        configureStatusItem()
        configureMenu()
    }

    func tearDown() {
        statusItem.menu = nil
        statusBar.removeStatusItem(statusItem)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "cat.fill", accessibilityDescription: "Naiku")
        button.toolTip = "Naiku"
        button.setAccessibilityLabel("Naiku menu")
    }

    private func configureMenu() {
        pauseMenuItem.target = self
        menu.addItem(pauseMenuItem)

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Naiku",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc
    private func togglePause() {
        isPaused.toggle()
        pauseMenuItem.title = isPaused ? "Resume Naiku" : "Pause Naiku"
        onPauseChanged(isPaused)
    }

    @objc
    private func showSettings() {
        onShowSettings()
    }

    @objc
    private func quit() {
        onQuit()
    }
}
