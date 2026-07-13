import CoreGraphics
import XCTest
@testable import Naiku

final class DesktopGeometryTests: XCTestCase {
    private let petSize = CGSize(width: 72, height: 72)

    func testOriginIsClampedSoWholePetRemainsInsideBounds() {
        let negativeDisplay = CGRect(x: -1_920, y: -200, width: 1_920, height: 1_080)

        XCTAssertEqual(
            DesktopGeometry.clampedOrigin(CGPoint(x: -2_500, y: -500), petSize: petSize, to: negativeDisplay),
            CGPoint(x: -1_920, y: -200)
        )
        XCTAssertEqual(
            DesktopGeometry.clampedOrigin(CGPoint(x: 100, y: 2_000), petSize: petSize, to: negativeDisplay),
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
