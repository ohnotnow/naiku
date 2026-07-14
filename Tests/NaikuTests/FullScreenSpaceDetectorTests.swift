import CoreGraphics
import XCTest
@testable import Naiku

final class FullScreenSpaceDetectorTests: XCTestCase {
    // A 1600x1000 primary display; Quartz coordinates in these fixtures use
    // its top-left as origin, so primaryDisplayMaxY is 1000.
    private let primaryDisplay = DisplayGeometry(
        frame: CGRect(x: 0, y: 0, width: 1600, height: 1000),
        visibleFrame: CGRect(x: 0, y: 70, width: 1600, height: 905)
    )
    private let primaryDisplayMaxY: CGFloat = 1000
    private let petFrame = CGRect(x: 100, y: 100, width: 72, height: 72)
    private let ownPID: pid_t = 999

    func testFullScreenWindowOnThePetDisplayIsDetected() {
        let fullScreen = record(CGRect(x: 0, y: 0, width: 1600, height: 1000))

        XCTAssertTrue(detect(records: [fullScreen]))
    }

    func testNotchInsetFullScreenWindowIsDetected() {
        let belowNotch = record(CGRect(x: 0, y: 32, width: 1600, height: 968))

        XCTAssertTrue(detect(records: [belowNotch]))
    }

    func testMaximisedWindowAboveTheDockIsNotFullScreen() {
        let maximised = record(CGRect(x: 0, y: 25, width: 1600, height: 905))

        XCTAssertFalse(detect(records: [maximised]))
    }

    func testFullScreenWindowOnAnotherDisplayIsIgnored() {
        let secondDisplay = DisplayGeometry(
            frame: CGRect(x: 1600, y: 0, width: 1600, height: 1000),
            visibleFrame: CGRect(x: 1600, y: 70, width: 1600, height: 905)
        )
        let fullScreenElsewhere = record(CGRect(x: 1600, y: 0, width: 1600, height: 1000))

        XCTAssertFalse(detect(records: [fullScreenElsewhere], displays: [primaryDisplay, secondDisplay]))
    }

    func testOwnWindowsAndNonNormalLayersAreIgnored() {
        let ownFullScreen = record(CGRect(x: 0, y: 0, width: 1600, height: 1000), pid: ownPID)
        let overlay = record(CGRect(x: 0, y: 0, width: 1600, height: 1000), layer: 25)
        let invisible = record(CGRect(x: 0, y: 0, width: 1600, height: 1000), alpha: 0)

        XCTAssertFalse(detect(records: [ownFullScreen, overlay, invisible]))
    }

    private func detect(
        records: [WindowGeometryRecord],
        displays: [DisplayGeometry]? = nil
    ) -> Bool {
        FullScreenSpaceDetector.hasFullScreenWindow(
            records: records,
            displays: displays ?? [primaryDisplay],
            primaryDisplayMaxY: primaryDisplayMaxY,
            near: petFrame,
            ownPID: ownPID
        )
    }

    private func record(
        _ quartzBounds: CGRect,
        layer: Int = 0,
        alpha: CGFloat = 1,
        pid: pid_t = 111
    ) -> WindowGeometryRecord {
        WindowGeometryRecord(
            id: 1,
            quartzBounds: quartzBounds,
            layer: layer,
            alpha: alpha,
            ownerPID: pid
        )
    }
}
