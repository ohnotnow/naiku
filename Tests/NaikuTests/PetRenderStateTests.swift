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
        XCTAssertEqual(PetRenderState.flourishing.animationID, .waving)
        XCTAssertEqual(PetRenderState.jumping.animationID, .jumping)
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

        view.update(renderState: .moving(.east))
        view.advanceFrame()
        XCTAssertEqual(view.frameIndex, 1)

        view.update(renderState: .moving(.northEast))
        XCTAssertEqual(view.frameIndex, 1)

        view.update(renderState: .moving(.west))
        XCTAssertEqual(view.frameIndex, 0)
    }

    func testSameAnimationDoesNotRequestAnUnnecessaryRedraw() throws {
        let frame = NSRect(origin: .zero, size: PetWindowController.petSize)
        let view = PetSpriteView(frame: frame, library: try makeLibrary())
        view.update(renderState: .moving(.east))
        view.needsDisplay = false

        view.update(renderState: .moving(.northEast))

        XCTAssertFalse(view.needsDisplay)
        XCTAssertEqual(view.renderState, .moving(.northEast))
    }

    func testVisibleCatRegionCanHandleAnArmedClick() throws {
        let frame = NSRect(origin: .zero, size: PetWindowController.petSize)
        let view = PetSpriteView(frame: frame, library: try makeLibrary())
        var clickCount = 0
        view.onClick = { clickCount += 1 }

        XCTAssertTrue(view.containsCat(at: CGPoint(x: 36, y: 40)))
        XCTAssertFalse(view.containsCat(at: CGPoint(x: 1, y: 1)))
        XCTAssertFalse(view.isAccessibilityElement())

        let event = try XCTUnwrap(NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: CGPoint(x: 36, y: 40),
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
