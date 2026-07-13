import AppKit

@MainActor
final class PetWindowController: NSWindowController {
    static let petSize = NSSize(width: 72, height: 72)
    static let frameInterval: TimeInterval = 1.0 / 30.0

    private var motionTimer: Timer?
    private let reduceMotionEnabled: @MainActor () -> Bool
    private(set) var isPaused = false
    private(set) var isInteractionActive = false
    private(set) var isReducedMotionActive = false

    var onPetClick: (@MainActor () -> Void)? {
        didSet { spriteView?.onClick = onPetClick }
    }

    var isEffectivelyPaused: Bool { isPaused || isInteractionActive }

    init(
        screen: NSScreen? = NSScreen.main,
        reduceMotionEnabled: @escaping @MainActor () -> Bool = {
            NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        }
    ) {
        self.reduceMotionEnabled = reduceMotionEnabled
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
        panel.ignoresMouseEvents = false
        panel.level = .floating

        // Naiku follows the user between normal Spaces and may appear beside a
        // full-screen app. `.ignoresCycle` keeps this utility panel out of ⌘-`.
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
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
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("PetWindowController does not support storyboards")
    }

    func show() {
        window?.orderFrontRegardless()
        applyRunningState()
    }

    func hide() {
        spriteView?.stopAnimating()
        window?.orderOut(nil)
    }

    func tearDown() {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        stopMotionTimer()
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
        window.setFrameOrigin(MotionEngine.clamp(origin: window.frame.origin, petSize: window.frame.size, to: bounds))
    }

    func refreshAccessibilityPreferences() {
        applyRunningState()
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

    private func stopMotionTimer() {
        motionTimer?.invalidate()
        motionTimer = nil
    }

    private func applyRunningState() {
        isReducedMotionActive = reduceMotionEnabled()
        if isEffectivelyPaused || isReducedMotionActive {
            stopMotionTimer()
            spriteView?.stopAnimating()
            spriteView?.resetToIdle()
        } else {
            spriteView?.startAnimating()
            startMotionTimerIfNeeded()
        }
    }

    @objc
    private func advanceMotion() {
        guard let window else { return }

        let target = NSEvent.mouseLocation
        let step = MotionEngine.step(
            from: window.frame.origin,
            toward: target,
            elapsed: Self.frameInterval,
            petSize: window.frame.size,
            within: DesktopGeometry.visibleBounds(containing: target)
        )
        window.setFrameOrigin(step.origin)
        spriteView?.update(direction: step.direction, isMoving: step.isMoving, elapsed: Self.frameInterval)
    }

    @objc
    private func screenParametersDidChange() {
        ensureVisible()
    }

    @objc
    private func accessibilityDisplayOptionsDidChange() {
        refreshAccessibilityPreferences()
    }

    private var spriteView: PetSpriteView? {
        window?.contentView as? PetSpriteView
    }
}
