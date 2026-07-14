import AppKit
import XCTest
@testable import Naiku

@MainActor
final class PetWindowControllerTests: XCTestCase {
    func testPanelIsTransparentFloatingAndNonActivating() throws {
        let controller = PetWindowController(screen: nil)
        let panel = try XCTUnwrap(controller.window as? PetPanel)

        XCTAssertFalse(panel.isOpaque)
        XCTAssertEqual(panel.backgroundColor, .clear)
        XCTAssertFalse(panel.hasShadow)
        XCTAssertFalse(panel.canBecomeKey)
        XCTAssertFalse(panel.canBecomeMain)
        XCTAssertTrue(panel.ignoresMouseEvents)
        XCTAssertEqual(panel.level, .floating)
        XCTAssertTrue(panel.styleMask.contains(.borderless))
        XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel))
        XCTAssertTrue(panel.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertFalse(panel.collectionBehavior.contains(.fullScreenAuxiliary))

        controller.tearDown()
    }

    func testFullScreenVisibilityPreferenceTogglesCollectionBehavior() throws {
        let controller = PetWindowController(screen: nil)
        let panel = try XCTUnwrap(controller.window)

        controller.setShowsOverFullScreenApps(true)
        XCTAssertTrue(panel.collectionBehavior.contains(.fullScreenAuxiliary))
        XCTAssertTrue(panel.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(panel.collectionBehavior.contains(.ignoresCycle))

        controller.setShowsOverFullScreenApps(false)
        XCTAssertFalse(panel.collectionBehavior.contains(.fullScreenAuxiliary))
        XCTAssertTrue(panel.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(panel.collectionBehavior.contains(.ignoresCycle))

        controller.tearDown()
    }

    func testWindowUsesTheExpectedPetSize() throws {
        let controller = PetWindowController(screen: nil)
        let window = try XCTUnwrap(controller.window)

        XCTAssertEqual(window.frame.size, PetWindowController.petSize)

        controller.tearDown()
    }

    func testBundledSpriteResourcesRenderVisiblePixels() throws {
        let frame = NSRect(origin: .zero, size: PetWindowController.petSize)
        let view = PetSpriteView(frame: frame)
        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: frame))

        XCTAssertFalse(view.hasMissingResources)
        view.cacheDisplay(in: frame, to: bitmap)

        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        XCTAssertGreaterThan(png.count, 500)
    }

    func testMissingSpritesRenderAnObviousMarker() throws {
        let frame = NSRect(origin: .zero, size: PetWindowController.petSize)
        let view = PetSpriteView(frame: frame, library: nil)
        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: frame))

        XCTAssertTrue(view.hasMissingResources)
        view.cacheDisplay(in: frame, to: bitmap)

        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        XCTAssertGreaterThan(png.count, 500)
    }

    func testPauseAndResumeAreIdempotent() {
        let controller = PetWindowController(screen: nil)

        controller.setPaused(true)
        controller.setPaused(true)
        XCTAssertTrue(controller.isPaused)

        controller.setPaused(false)
        controller.setPaused(false)
        XCTAssertFalse(controller.isPaused)

        controller.tearDown()
    }

    func testInteractionPauseDoesNotOverrideUserPause() {
        let controller = PetWindowController(screen: nil)

        controller.beginInteraction()
        XCTAssertTrue(controller.isEffectivelyPaused)
        controller.endInteraction()
        XCTAssertFalse(controller.isEffectivelyPaused)

        controller.setPaused(true)
        controller.beginInteraction()
        controller.endInteraction()
        XCTAssertTrue(controller.isEffectivelyPaused)
        XCTAssertTrue(controller.isPaused)

        controller.tearDown()
    }

    func testEnsureVisibleRecoversPetOntoNearestRemainingDisplay() throws {
        let controller = PetWindowController(screen: nil)
        let window = try XCTUnwrap(controller.window)
        window.setFrameOrigin(CGPoint(x: -2_000, y: 1_500))
        let visible = CGRect(x: 0, y: 24, width: 1_440, height: 852)

        controller.ensureVisible(
            displays: [DisplayGeometry(frame: CGRect(x: 0, y: 0, width: 1_440, height: 900), visibleFrame: visible)],
            fallback: visible
        )

        XCTAssertTrue(visible.contains(window.frame))
        controller.tearDown()
    }

    func testReducedMotionStopsAutomaticPetAnimation() {
        let preference = MotionPreferenceStub(enabled: true)
        let controller = PetWindowController(screen: nil, reduceMotionEnabled: { preference.enabled })

        controller.show()
        XCTAssertTrue(controller.isReducedMotionActive)

        preference.enabled = false
        controller.refreshAccessibilityPreferences()
        XCTAssertFalse(controller.isReducedMotionActive)
        controller.tearDown()
    }
}

@MainActor
private final class MotionPreferenceStub {
    var enabled: Bool

    init(enabled: Bool) {
        self.enabled = enabled
    }
}
