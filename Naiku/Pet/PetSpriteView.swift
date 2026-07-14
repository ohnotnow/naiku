import AppKit

/// Renders the bundled data-driven atlas. Motion chooses an animation while
/// this view owns its variable frame cadence, keeping physics and art separate.
@MainActor
final class PetSpriteView: NSView {
    private let library: PetAnimationLibrary?
    private var animationTimer: Timer?

    private(set) var renderState = PetRenderState.idle
    private(set) var frameIndex = 0
    var hasMissingResources: Bool { library == nil }
    var onClick: (@MainActor () -> Void)?

    override convenience init(frame frameRect: NSRect) {
        self.init(frame: frameRect, library: PetAnimationLibrary.bundled())
    }

    init(frame frameRect: NSRect, library: PetAnimationLibrary?) {
        self.library = library
        super.init(frame: frameRect)
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("PetSpriteView does not support storyboards")
    }

    override var isOpaque: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        containsCat(at: point) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        guard containsCat(at: convert(event.locationInWindow, from: nil)) else { return }
        onClick?()
    }

    func containsCat(at point: CGPoint) -> Bool {
        bounds.contains(point) && visibleCatRegion.contains(point)
    }

    func update(renderState nextState: PetRenderState) {
        let animationChanged = nextState.animationID != renderState.animationID
        renderState = nextState
        guard animationChanged else { return }

        frameIndex = 0
        rescheduleAnimationIfNeeded()
        needsDisplay = true
    }

    func resetToIdle() {
        if renderState.animationID != PetAnimationID.idle {
            frameIndex = 0
        }
        renderState = .idle
        rescheduleAnimationIfNeeded()
        needsDisplay = true
    }

    func startAnimating() {
        guard animationTimer == nil else { return }
        scheduleNextFrame()
    }

    func stopAnimating() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    @objc
    func advanceFrame() {
        guard let animation = currentAnimation, animation.frameCount > 0 else { return }
        frameIndex = (frameIndex + 1) % animation.frameCount
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard
            let library,
            let sourceRect = library.manifest.sourceRect(for: renderState.animationID, frameIndex: frameIndex)
        else {
            drawMissingResourceMarker()
            return
        }

        guard let graphicsContext = NSGraphicsContext.current else { return }
        graphicsContext.saveGraphicsState()
        graphicsContext.imageInterpolation = .none
        library.image.draw(
            in: aspectFitRect(for: sourceRect.size),
            from: sourceRect,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.none.rawValue]
        )
        graphicsContext.restoreGraphicsState()
    }

    private var currentAnimation: PetAnimation? {
        library?.manifest.animation(renderState.animationID)
    }

    private func frameDuration() -> TimeInterval? {
        guard let animation = currentAnimation, !animation.frameDurations.isEmpty else { return nil }
        return TimeInterval(animation.frameDurations[frameIndex % animation.frameCount]) / 1_000
    }

    private func scheduleNextFrame() {
        guard animationTimer == nil, let duration = frameDuration() else { return }
        let timer = Timer(timeInterval: duration, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.animationTimer = nil
                self.advanceFrame()
                self.scheduleNextFrame()
            }
        }
        timer.tolerance = min(duration * 0.1, 0.02)
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }

    private func rescheduleAnimationIfNeeded() {
        guard animationTimer != nil else { return }
        stopAnimating()
        startAnimating()
    }

    private func aspectFitRect(for sourceSize: NSSize) -> NSRect {
        let scale = min(bounds.width / sourceSize.width, bounds.height / sourceSize.height)
        let size = NSSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        return NSRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2, width: size.width, height: size.height)
    }

    private func drawMissingResourceMarker() {
        NSColor.systemPink.setFill()
        bounds.fill()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 40),
            .foregroundColor: NSColor.white,
        ]
        let marker = NSAttributedString(string: "!", attributes: attributes)
        let size = marker.size()
        marker.draw(at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2))
    }

    private var visibleCatRegion: NSBezierPath {
        let region = NSBezierPath()
        region.appendOval(in: NSRect(x: 13, y: 27, width: 48, height: 43))
        region.appendRoundedRect(NSRect(x: 12, y: 4, width: 49, height: 48), xRadius: 14, yRadius: 14)
        region.appendOval(in: NSRect(x: 50, y: 24, width: 22, height: 37))
        return region
    }
}
