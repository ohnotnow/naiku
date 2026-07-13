import AppKit
import XCTest
@testable import Naiku

@MainActor
final class ApplicationMenuTests: XCTestCase {
    func testEditMenuProvidesStandardTextEditingCommands() throws {
        let mainMenu = ApplicationMenu.make()
        let editMenu = try XCTUnwrap(mainMenu.items.first?.submenu)

        assertMenuItem(
            titled: "Cut",
            action: #selector(NSText.cut(_:)),
            keyEquivalent: "x",
            in: editMenu
        )
        assertMenuItem(
            titled: "Copy",
            action: #selector(NSText.copy(_:)),
            keyEquivalent: "c",
            in: editMenu
        )
        assertMenuItem(
            titled: "Paste",
            action: #selector(NSText.paste(_:)),
            keyEquivalent: "v",
            in: editMenu
        )
        assertMenuItem(
            titled: "Select All",
            action: #selector(NSText.selectAll(_:)),
            keyEquivalent: "a",
            in: editMenu
        )
    }

    private func assertMenuItem(
        titled title: String,
        action: Selector,
        keyEquivalent: String,
        in menu: NSMenu,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let item = menu.items.first(where: { $0.title == title }) else {
            return XCTFail("Missing \(title) menu item", file: file, line: line)
        }
        XCTAssertEqual(item.action, action, file: file, line: line)
        XCTAssertEqual(item.keyEquivalent, keyEquivalent, file: file, line: line)
        XCTAssertTrue(item.keyEquivalentModifierMask.contains(.command), file: file, line: line)
        XCTAssertNil(item.target, file: file, line: line)
    }
}
