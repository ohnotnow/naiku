import XCTest
@testable import Naiku

final class AppIdentityTests: XCTestCase {
    func testDisplayName() {
        XCTAssertEqual(AppIdentity.displayName, "Naiku")
    }

    func testUnitTestHostIsDetected() {
        XCTAssertTrue(AppRuntime.isRunningUnitTests)
    }
}
