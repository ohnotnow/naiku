import AppKit
import KeyboardShortcuts

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let hasPresentedWelcomeKey = "hasPresentedWelcome"
    private var petWindowController: PetWindowController?
    private var settingsWindowController: SettingsWindowController?
    private var statusMenuController: StatusMenuController?
    private var settingsModel: SettingsModel?
    private var chatSessionModel: ChatSessionModel?
    private var chatPanelController: ChatPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !AppRuntime.isRunningUnitTests else { return }

        let petController = PetWindowController()
        let preferences = AppPreferences()
        let model = SettingsModel(
            keyStore: KeychainAPIKeyStore(),
            preferences: preferences,
            onFullScreenVisibilityChanged: { [weak petController] shows in
                petController?.setShowsOverFullScreenApps(shows)
            }
        )
        petController.setShowsOverFullScreenApps(preferences.showsOverFullScreenApps)
        let settingsController = SettingsWindowController(model: model)
        let chatSession = ChatSessionModel(
            settings: model,
            providers: [
                .anthropic: AnthropicChatProvider(),
                .openAI: OpenAIChatProvider(),
            ]
        )
        let chatController = ChatPanelController(
            session: chatSession,
            onOpenSettings: { [weak settingsController] in
                settingsController?.show()
            },
            onClose: { [weak petController] in
                petController?.endInteraction()
            }
        )
        model.setProviderChangeHandler { [weak chatSession] in
            chatSession?.newConversation()
        }
        let showChat: @MainActor () -> Void = { [weak petController, weak chatController] in
            petController?.beginInteraction()
            chatController?.show(near: petController?.window?.frame)
        }
        petController.onPetClick = showChat
        KeyboardShortcuts.onKeyUp(for: .openChat, action: showChat)
        let statusController = StatusMenuController(
            onShowChat: showChat,
            onPauseChanged: { [weak petController] isPaused in
                petController?.setPaused(isPaused)
            },
            onShowSettings: { [weak settingsController] in
                settingsController?.show()
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )

        petController.show()
        if !UserDefaults.standard.bool(forKey: Self.hasPresentedWelcomeKey) {
            settingsController.show()
            UserDefaults.standard.set(true, forKey: Self.hasPresentedWelcomeKey)
        }
        petWindowController = petController
        settingsModel = model
        chatSessionModel = chatSession
        chatPanelController = chatController
        settingsWindowController = settingsController
        statusMenuController = statusController
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusMenuController?.tearDown()
        statusMenuController = nil
        chatPanelController?.tearDown()
        chatPanelController = nil
        chatSessionModel = nil
        settingsWindowController?.close()
        settingsWindowController = nil
        settingsModel = nil
        petWindowController?.tearDown()
        petWindowController = nil
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
