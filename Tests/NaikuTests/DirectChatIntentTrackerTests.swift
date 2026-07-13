import CoreGraphics
import XCTest
@testable import Naiku

final class DirectChatIntentTrackerTests: XCTestCase {
    func testCatMovingUnderStationaryPointerNeverArms() {
        var tracker = DirectChatIntentTracker(dwellDuration: 0.6)
        let pointer = CGPoint(x: 40, y: 40)

        XCTAssertFalse(tracker.update(
            pointer: pointer,
            petOrigin: .zero,
            isPointerOnCat: false,
            isPetStationary: false,
            elapsed: 0.1
        ))
        XCTAssertFalse(tracker.update(
            pointer: pointer,
            petOrigin: CGPoint(x: 20, y: 20),
            isPointerOnCat: true,
            isPetStationary: false,
            elapsed: 0.1
        ))

        for _ in 0..<10 {
            XCTAssertFalse(tracker.update(
                pointer: pointer,
                petOrigin: CGPoint(x: 20, y: 20),
                isPointerOnCat: true,
                isPetStationary: true,
                elapsed: 0.1
            ))
        }
        XCTAssertFalse(tracker.isArmed)
    }

    func testPointerEntryAndDwellArmsChat() {
        var tracker = DirectChatIntentTracker(dwellDuration: 0.6)
        let pet = CGPoint(x: 100, y: 100)

        XCTAssertFalse(tracker.update(
            pointer: CGPoint(x: 90, y: 90),
            petOrigin: pet,
            isPointerOnCat: false,
            isPetStationary: true,
            elapsed: 0.1
        ))
        XCTAssertFalse(tracker.update(
            pointer: CGPoint(x: 120, y: 120),
            petOrigin: pet,
            isPointerOnCat: true,
            isPetStationary: true,
            elapsed: 0.1
        ))

        for _ in 0..<5 {
            XCTAssertFalse(tracker.update(
                pointer: CGPoint(x: 120, y: 120),
                petOrigin: pet,
                isPointerOnCat: true,
                isPetStationary: true,
                elapsed: 0.1
            ))
        }
        XCTAssertTrue(tracker.update(
            pointer: CGPoint(x: 120, y: 120),
            petOrigin: pet,
            isPointerOnCat: true,
            isPetStationary: true,
            elapsed: 0.1
        ))
        XCTAssertTrue(tracker.isArmed)
    }

    func testPointerExitAndPetMovementDisarm() {
        var tracker = armedTracker()

        XCTAssertFalse(tracker.update(
            pointer: CGPoint(x: 200, y: 200),
            petOrigin: .zero,
            isPointerOnCat: false,
            isPetStationary: true,
            elapsed: 0.1
        ))
        XCTAssertFalse(tracker.isArmed)

        tracker = armedTracker()
        XCTAssertFalse(tracker.update(
            pointer: CGPoint(x: 20, y: 20),
            petOrigin: CGPoint(x: 2, y: 0),
            isPointerOnCat: true,
            isPetStationary: false,
            elapsed: 0.1
        ))
        XCTAssertFalse(tracker.isArmed)
    }

    private func armedTracker() -> DirectChatIntentTracker {
        var tracker = DirectChatIntentTracker(dwellDuration: 0.2)
        _ = tracker.update(
            pointer: CGPoint(x: -10, y: -10),
            petOrigin: .zero,
            isPointerOnCat: false,
            isPetStationary: true,
            elapsed: 0.1
        )
        _ = tracker.update(
            pointer: CGPoint(x: 20, y: 20),
            petOrigin: .zero,
            isPointerOnCat: true,
            isPetStationary: true,
            elapsed: 0.1
        )
        _ = tracker.update(
            pointer: CGPoint(x: 20, y: 20),
            petOrigin: .zero,
            isPointerOnCat: true,
            isPetStationary: true,
            elapsed: 0.1
        )
        _ = tracker.update(
            pointer: CGPoint(x: 20, y: 20),
            petOrigin: .zero,
            isPointerOnCat: true,
            isPetStationary: true,
            elapsed: 0.1
        )
        return tracker
    }
}
