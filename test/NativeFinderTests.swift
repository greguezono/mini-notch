import XCTest
import AppKit
@testable import MiniNotch

final class NativeFinderTests: XCTestCase {
    func testPostingPermissionRequestsOnlyWhenMissingAndHonorsDenial() {
        for allowed in [false, true] {
            for granted in [false, true] {
                var requests = 0
                let check = { try NativeFinder.requirePostingAccess(preflight: { allowed }, request: { requests += 1; return granted }) }
                if allowed || granted { XCTAssertNoThrow(try check()) }
                else { XCTAssertThrowsError(try check()) }
                XCTAssertEqual(requests, allowed ? 0 : 1)
            }
        }
    }
    func testHiddenShortcutUsesCommandShiftPeriod() throws {
        let events = try NativeFinder.hiddenFileShortcut()
        XCTAssertEqual(events.down.type, .keyDown)
        XCTAssertEqual(events.up.type, .keyUp)
        for event in [events.down, events.up] {
            XCTAssertEqual(event.getIntegerValueField(.keyboardEventKeycode), 47)
            XCTAssertEqual(event.flags, [.maskCommand, .maskShift])
        }
    }
    func testAccessibilityDenialCarriesRecoveryAndRequestsEachTime() {
        var requests = 0
        for _ in 0..<2 {
            XCTAssertThrowsError(try NativeFinder.requirePostingAccess(preflight: { false }, request: { requests += 1; return false })) {
                XCTAssertEqual(($0 as? ActionError)?.recovery, .accessibility)
            }
        }
        XCTAssertEqual(requests, 2)
    }
    func testDeniedToggleNeverPosts() {
        var posts = 0
        XCTAssertThrowsError(try NativeFinder.toggle(finder: 1, access: { throw ActionError("denied", recovery: .accessibility) }, post: { _, _ in posts += 1 })) {
            XCTAssertEqual(($0 as? ActionError)?.recovery, .accessibility)
        }
        XCTAssertEqual(posts, 0)
        XCTAssertThrowsError(try NativeFinder.toggle(finder: nil, access: { XCTFail("access checked without Finder") }, post: { _, _ in XCTFail("posted without Finder") })) {
            XCTAssertNil(($0 as? ActionError)?.recovery)
        }
        XCTAssertNoThrow(try NativeFinder.toggle(finder: 1, access: {}, post: { _, _ in posts += 1 }))
        XCTAssertEqual(posts, 2)
    }
    func testSettingsDestinations() {
        XCTAssertEqual(PermissionRecovery.accessibility.settingsURL.absoluteString, "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        XCTAssertEqual(PermissionRecovery.automation.settingsURL.absoluteString, "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
    }
}
