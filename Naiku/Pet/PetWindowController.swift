import AppKit

@MainActor
final class PetWindowController: NSWindowController {
    static let petSize = NSSize(width: 72, height: 72)
    static let frameInterval: TimeInterval = 1.0 / 30.0
    static let terrainRefreshInterval: TimeInterval = 0.5

    private var motionTimer: Timer?
    private var terrainTimer: Timer?
    private var suppressionRecheckTimer: Timer?
    private var behaviorEngine: PeripheralBehaviorEngine
    private var directChatIntent = DirectChatIntentTracker()
    private let reduceMotionEnabled: @MainActor () -> Bool
    private let terrainProvider: WindowTerrainProviding
    private let decisionProvider: @MainActor () -> PeripheralDecisionValues
    private(set) var isPaused = false
    private(set) var isInteractionActive = false
    private(set) var isReducedMotionActive = false
    private(set) var showsOverFullScreenApps = false
    private(set) var isFullScreenSuppressed = false
    private(set) var terrainSnapshot = TerrainSnapshot(surfaces: [])
    private(set) var isDirectChatArmed = false

    var onPetClick: (@MainActor () -> Void)? {
        didSet { spriteView?.onClick = onPetClick }
    }

    var isEffectivelyPaused: Bool { isPaused || isInteractionActive }

    init(
        screen: NSScreen? = NSScreen.main,
        terrainProvider: WindowTerrainProviding? = nil,
        behaviorEngine: PeripheralBehaviorEngine = PeripheralBehaviorEngine(),
        decisionProvider: @escaping @MainActor () -> PeripheralDecisionValues = {
            PeripheralDecisionValues.random()
        },
        reduceMotionEnabled: @escaping @MainActor () -> Bool = {
            NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        }
    ) {
        self.reduceMotionEnabled = reduceMotionEnabled
        self.terrainProvider = terrainProvider ?? CoreGraphicsWindowTerrainProvider()
        self.behaviorEngine = behaviorEngine
        self.decisionProvider = decisionProvider
        let panel = PetPanel(
            contentRect: NSRect(origin: .zero, size: Self.petSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.ignoresMouseEvents = true
        panel.level = .floating

        // Naiku follows the user between normal Spaces, and stays away from
        // full-screen apps unless the preference allows it (applied after
        // launch via `setShowsOverFullScreenApps`). `.ignoresCycle` keeps
        // this utility panel out of ⌘-`.
        panel.collectionBehavior = Self.collectionBehavior(showsOverFullScreenApps: false)
        panel.contentView = PetSpriteView(frame: NSRect(origin: .zero, size: Self.petSize))

        super.init(window: panel)
        positionInitially(on: screen)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(accessibilityDisplayOptionsDidChange),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeSpaceDidChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("PetWindowController does not support storyboards")
    }

    func show() {
        window?.orderFrontRegardless()
        applyRunningState()
        updateFullScreenSuppression()
    }

    func hide() {
        disarmDirectChat()
        spriteView?.stopAnimating()
        stopTerrainTimer()
        stopSuppressionRecheckTimer()
        window?.orderOut(nil)
    }

    func tearDown() {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        stopMotionTimer()
        stopTerrainTimer()
        stopSuppressionRecheckTimer()
        disarmDirectChat()
        spriteView?.stopAnimating()
        window?.orderOut(nil)
        window?.contentView = nil
        close()
    }

    func setPaused(_ paused: Bool) {
        guard paused != isPaused else { return }
        isPaused = paused

        applyRunningState()
    }

    func beginInteraction() {
        disarmDirectChat()
        guard !isInteractionActive else { return }
        isInteractionActive = true
        applyRunningState()
    }

    func endInteraction() {
        guard isInteractionActive else { return }
        isInteractionActive = false
        applyRunningState()
    }

    func ensureVisible(displays: [DisplayGeometry]? = nil, fallback: CGRect? = nil) {
        guard let window else { return }
        let availableDisplays = displays ?? DesktopGeometry.currentDisplays
        let fallbackBounds = fallback ?? NSScreen.main?.visibleFrame ?? .zero
        let bounds = DesktopGeometry.nearestVisibleBounds(
            to: window.frame,
            displays: availableDisplays,
            fallback: fallbackBounds
        )
        window.setFrameOrigin(DesktopGeometry.clampedOrigin(
            window.frame.origin,
            petSize: window.frame.size,
            to: bounds
        ))
    }

    func refreshAccessibilityPreferences() {
        applyRunningState()
    }

    func setShowsOverFullScreenApps(_ shows: Bool) {
        showsOverFullScreenApps = shows
        window?.collectionBehavior = Self.collectionBehavior(showsOverFullScreenApps: shows)
        updateFullScreenSuppression()
    }

    private static func collectionBehavior(showsOverFullScreenApps: Bool) -> NSWindow.CollectionBehavior {
        var behavior: NSWindow.CollectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
        if showsOverFullScreenApps {
            behavior.insert(.fullScreenAuxiliary)
        }
        return behavior
    }

    private func positionInitially(on screen: NSScreen?) {
        guard let visibleFrame = screen?.visibleFrame else { return }

        let origin = NSPoint(
            x: visibleFrame.maxX - Self.petSize.width - 40,
            y: visibleFrame.minY + 80
        )
        window?.setFrameOrigin(origin)
    }

    private func startMotionTimerIfNeeded() {
        guard motionTimer == nil, !isEffectivelyPaused, window?.isVisible == true else { return }

        let timer = Timer(
            timeInterval: Self.frameInterval,
            target: self,
            selector: #selector(advanceMotion),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        motionTimer = timer
    }

    private func startTerrainTimerIfNeeded() {
        guard terrainTimer == nil, !isEffectivelyPaused, window?.isVisible == true else { return }

        refreshTerrain()
        let timer = Timer(
            timeInterval: Self.terrainRefreshInterval,
            target: self,
            selector: #selector(refreshTerrain),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        terrainTimer = timer
    }

    private func stopMotionTimer() {
        motionTimer?.invalidate()
        motionTimer = nil
    }

    private func stopTerrainTimer() {
        terrainTimer?.invalidate()
        terrainTimer = nil
    }

    @objc
    func refreshTerrain() {
        terrainSnapshot = terrainProvider.snapshot(petSize: Self.petSize)
    }

    private func applyRunningState() {
        isReducedMotionActive = reduceMotionEnabled()
        if isEffectivelyPaused || isReducedMotionActive || isFullScreenSuppressed {
            disarmDirectChat()
            stopMotionTimer()
            stopTerrainTimer()
            spriteView?.stopAnimating()
            spriteView?.resetToIdle()
        } else {
            spriteView?.startAnimating()
            startTerrainTimerIfNeeded()
            startMotionTimerIfNeeded()
        }
    }

    @objc
    private func advanceMotion() {
        guard let window else { return }

        let pointer = NSEvent.mouseLocation
        let step = behaviorEngine.step(
            from: window.frame.origin,
            pointer: pointer,
            elapsed: Self.frameInterval,
            petSize: window.frame.size,
            terrain: terrainSnapshot,
            decision: decisionProvider()
        )
        window.setFrameOrigin(step.origin)
        let localPointer = CGPoint(
            x: pointer.x - step.origin.x,
            y: pointer.y - step.origin.y
        )
        let pointerIsOnCat = spriteView?.containsCat(at: localPointer) == true
        isDirectChatArmed = directChatIntent.update(
            pointer: pointer,
            petOrigin: step.origin,
            isPointerOnCat: pointerIsOnCat,
            isPetStationary: step.activity.isStationary,
            elapsed: Self.frameInterval
        )
        window.ignoresMouseEvents = !isDirectChatArmed
        spriteView?.update(renderState: isDirectChatArmed ? .flourishing : step.renderState)
    }

    @objc
    private func screenParametersDidChange() {
        ensureVisible()
        refreshTerrain()
    }

    @objc
    private func activeSpaceDidChange() {
        updateFullScreenSuppression()
        // Space transitions animate, and the window list can still show the
        // departing Space's contents when the notification arrives. Check
        // again once the transition has settled.
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(800))
            self?.updateFullScreenSuppression()
        }
    }

    /// A `.canJoinAllSpaces` floating panel appears over full-screen apps
    /// whether or not it declares `.fullScreenAuxiliary`, so staying out of
    /// full-screen needs an active check: when the user lands on a Space
    /// showing a full-screen window, Naiku steps off screen until they leave.
    private func updateFullScreenSuppression() {
        guard !AppRuntime.isRunningUnitTests else { return }
        guard let window else { return }

        let suppressed = !showsOverFullScreenApps
            && terrainProvider.hasFullScreenWindow(near: window.frame)
        guard suppressed != isFullScreenSuppressed else { return }

        isFullScreenSuppressed = suppressed
        if suppressed {
            window.orderOut(nil)
            startSuppressionRecheckTimerIfNeeded()
        } else {
            stopSuppressionRecheckTimer()
            window.orderFrontRegardless()
        }
        applyRunningState()
    }

    /// While the cat is hidden its motion and terrain timers are stopped, so
    /// nothing else would notice the full-screen window going away — and the
    /// Space-change notification can arrive before the window list reflects
    /// the change. A slow recheck closes both gaps.
    private func startSuppressionRecheckTimerIfNeeded() {
        guard suppressionRecheckTimer == nil else { return }

        let timer = Timer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(recheckSuppression),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        suppressionRecheckTimer = timer
    }

    private func stopSuppressionRecheckTimer() {
        suppressionRecheckTimer?.invalidate()
        suppressionRecheckTimer = nil
    }

    @objc
    private func recheckSuppression() {
        updateFullScreenSuppression()
    }

    @objc
    private func accessibilityDisplayOptionsDidChange() {
        refreshAccessibilityPreferences()
    }

    private var spriteView: PetSpriteView? {
        window?.contentView as? PetSpriteView
    }

    private func disarmDirectChat() {
        directChatIntent.reset()
        isDirectChatArmed = false
        window?.ignoresMouseEvents = true
    }
}
