import AppKit
import XCTest
@testable import Naiku

@MainActor
final class PetRenderStateTests: XCTestCase {
    func testMotionMapsToDirectionalAtlasRows() {
        XCTAssertEqual(PetRenderState.moving(.east).animationID, .runningRight)
        XCTAssertEqual(PetRenderState.moving(.northWest).animationID, .runningLeft)
        XCTAssertEqual(PetRenderState.moving(.north).animationID, .running)
        XCTAssertEqual(PetRenderState.idle.animationID, .idle)
        XCTAssertEqual(PetRenderState.resting.animationID, .waiting)
    }

    func testRestingTransitionIsDeterministic() {
        var behavior = PetBehaviorStateMachine()

        XCTAssertEqual(behavior.update(direction: .idle, isMoving: false, elapsed: 3.9), .idle)
        XCTAssertEqual(behavior.update(direction: .idle, isMoving: false, elapsed: 0.1), .resting)
        XCTAssertEqual(behavior.update(direction: .east, isMoving: true, elapsed: 0.1), .moving(.east))
        XCTAssertEqual(behavior.update(direction: .idle, isMoving: false, elapsed: 0.1), .idle)
    }

    func testManifestDecodesAndCalculatesTopOriginRows() throws {
        let data = try XCTUnwrap(Self.manifestJSON.data(using: .utf8))
        let manifest = try JSONDecoder().decode(PetAnimationManifest.self, from: data)

        XCTAssertEqual(manifest.animation(.idle)?.frameCount, 2)
        XCTAssertEqual(manifest.sourceRect(for: .idle, frameIndex: 1), NSRect(x: 192, y: 1_664, width: 192, height: 208))
        XCTAssertEqual(manifest.sourceRect(for: .waiting, frameIndex: 0), NSRect(x: 0, y: 416, width: 192, height: 208))
    }

    func testAnimationDoesNotRestartWithinTheSameAtlasRow() throws {
        let frame = NSRect(origin: .zero, size: PetWindowController.petSize)
        let view = PetSpriteView(frame: frame, library: try makeLibrary())

        view.update(direction: .east, isMoving: true)
        view.advanceFrame()
        XCTAssertEqual(view.frameIndex, 1)

        view.update(direction: .northEast, isMoving: true)
        XCTAssertEqual(view.frameIndex, 1)

        view.update(direction: .west, isMoving: true)
        XCTAssertEqual(view.frameIndex, 0)
    }

    func testOnlyTheVisibleCatRegionAcceptsClicks() throws {
        let frame = NSRect(origin: .zero, size: PetWindowController.petSize)
        let view = PetSpriteView(frame: frame, library: try makeLibrary())
        var clickCount = 0
        view.onClick = { clickCount += 1 }

        XCTAssertTrue(view.hitTest(NSPoint(x: 36, y: 40)) === view)
        XCTAssertNil(view.hitTest(NSPoint(x: 1, y: 1)))

        let event = try XCTUnwrap(NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: NSPoint(x: 36, y: 40),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 1
        ))
        view.mouseDown(with: event)
        XCTAssertEqual(clickCount, 1)

        XCTAssertEqual(view.accessibilityRole(), .button)
        XCTAssertEqual(view.accessibilityLabel(), "Naiku")
        XCTAssertTrue(view.accessibilityPerformPress())
        XCTAssertEqual(clickCount, 2)
    }

    private func makeLibrary() throws -> PetAnimationLibrary {
        let data = try XCTUnwrap(Self.manifestJSON.data(using: .utf8))
        let manifest = try JSONDecoder().decode(PetAnimationManifest.self, from: data)
        return PetAnimationLibrary(image: NSImage(size: NSSize(width: 1_536, height: 1_872)), manifest: manifest)
    }

    private static let manifestJSON = """
    {
      "atlasWidth": 1536,
      "atlasHeight": 1872,
      "cellWidth": 192,
      "cellHeight": 208,
      "animations": {
        "idle": { "row": 0, "frameDurations": [100, 200] },
        "running-right": { "row": 1, "frameDurations": [100, 100] },
        "running-left": { "row": 2, "frameDurations": [100, 100] },
        "waiting": { "row": 6, "frameDurations": [100, 100] },
        "running": { "row": 7, "frameDurations": [100, 100] }
      }
    }
    """
}
