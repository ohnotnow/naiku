import CoreGraphics
import XCTest
@testable import Naiku

final class MotionEngineTests: XCTestCase {
    private let bounds = CGRect(x: 0, y: 0, width: 1_000, height: 800)
    private let petSize = CGSize(width: 72, height: 72)

    func testDirectionUsesAppKitCoordinateOrientation() {
        XCTAssertEqual(MotionEngine.direction(dx: 1, dy: 0), .east)
        XCTAssertEqual(MotionEngine.direction(dx: 1, dy: 1), .northEast)
        XCTAssertEqual(MotionEngine.direction(dx: 0, dy: 1), .north)
        XCTAssertEqual(MotionEngine.direction(dx: -1, dy: -1), .southWest)
        XCTAssertEqual(MotionEngine.direction(dx: 0, dy: -1), .south)
    }

    func testStepMovesTowardTargetAtConfiguredSpeed() {
        let step = MotionEngine.step(
            from: CGPoint(x: 100, y: 100),
            toward: CGPoint(x: 500, y: 136),
            elapsed: 0.5,
            petSize: petSize,
            within: bounds,
            configuration: MotionConfiguration(speed: 100, stoppingDistance: 20)
        )

        XCTAssertEqual(step.origin.x, 150, accuracy: 0.001)
        XCTAssertEqual(step.origin.y, 100, accuracy: 0.001)
        XCTAssertEqual(step.direction, .east)
        XCTAssertTrue(step.isMoving)
    }

    func testCatStopsWithoutJitterInsideStoppingDistance() {
        let origin = CGPoint(x: 100, y: 100)
        let step = MotionEngine.step(
            from: origin,
            toward: CGPoint(x: 145, y: 136),
            elapsed: 1,
            petSize: petSize,
            within: bounds,
            configuration: MotionConfiguration(speed: 500, stoppingDistance: 20)
        )

        XCTAssertEqual(step.origin, origin)
        XCTAssertEqual(step.direction, .idle)
        XCTAssertFalse(step.isMoving)
    }

    func testLargeTimeStepStopsAtConfiguredDistanceRatherThanOvershooting() {
        let step = MotionEngine.step(
            from: CGPoint(x: 100, y: 100),
            toward: CGPoint(x: 500, y: 136),
            elapsed: 10,
            petSize: petSize,
            within: bounds,
            configuration: MotionConfiguration(speed: 500, stoppingDistance: 24)
        )

        let resultingCenterX = step.origin.x + petSize.width / 2
        XCTAssertEqual(500 - resultingCenterX, 24, accuracy: 0.001)
    }

    func testOriginIsClampedSoWholePetRemainsInsideBounds() {
        let negativeDisplay = CGRect(x: -1_920, y: -200, width: 1_920, height: 1_080)

        XCTAssertEqual(
            MotionEngine.clamp(origin: CGPoint(x: -2_500, y: -500), petSize: petSize, to: negativeDisplay),
            CGPoint(x: -1_920, y: -200)
        )
        XCTAssertEqual(
            MotionEngine.clamp(origin: CGPoint(x: 100, y: 2_000), petSize: petSize, to: negativeDisplay),
            CGPoint(x: -72, y: 808)
        )
    }

    func testDisplayLookupSupportsNegativeAndVerticalOrigins() {
        let displays = [
            DisplayGeometry(
                frame: CGRect(x: 0, y: 0, width: 1_440, height: 900),
                visibleFrame: CGRect(x: 0, y: 24, width: 1_440, height: 852)
            ),
            DisplayGeometry(
                frame: CGRect(x: -1_920, y: -200, width: 1_920, height: 1_080),
                visibleFrame: CGRect(x: -1_920, y: -176, width: 1_920, height: 1_056)
            ),
            DisplayGeometry(
                frame: CGRect(x: 300, y: 900, width: 1_280, height: 720),
                visibleFrame: CGRect(x: 300, y: 900, width: 1_280, height: 696)
            ),
        ]

        XCTAssertEqual(
            DesktopGeometry.visibleBounds(containing: CGPoint(x: -500, y: -100), displays: displays, fallback: .zero),
            displays[1].visibleFrame
        )
        XCTAssertEqual(
            DesktopGeometry.visibleBounds(containing: CGPoint(x: 700, y: 1_200), displays: displays, fallback: .zero),
            displays[2].visibleFrame
        )
    }

    func testNearestDisplayRecoversAWindowAfterDisconnectOrRearrangement() {
        let displays = [
            DisplayGeometry(
                frame: CGRect(x: 0, y: 0, width: 1_440, height: 900),
                visibleFrame: CGRect(x: 0, y: 24, width: 1_440, height: 852)
            ),
            DisplayGeometry(
                frame: CGRect(x: 0, y: -1_080, width: 1_920, height: 1_080),
                visibleFrame: CGRect(x: 0, y: -1_056, width: 1_920, height: 1_056)
            ),
        ]

        XCTAssertEqual(
            DesktopGeometry.nearestVisibleBounds(
                to: CGRect(x: -2_000, y: 200, width: 72, height: 72),
                displays: displays,
                fallback: .zero
            ),
            displays[0].visibleFrame
        )
        XCTAssertEqual(
            DesktopGeometry.nearestVisibleBounds(
                to: CGRect(x: 500, y: -900, width: 430, height: 500),
                displays: displays,
                fallback: .zero
            ),
            displays[1].visibleFrame
        )
    }
}
