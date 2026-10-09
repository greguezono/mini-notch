import XCTest
import AppKit
@testable import MiniNotch

final class SystemActionsTests: XCTestCase {
    @MainActor func testHiddenShortcutRunsWithoutConfirmationAndSuppressesDuplicates() async {
        var calls = 0
        let actions = SystemActions(toggleHidden: { calls += 1 }, trash: {})
        XCTAssertFalse(actions.hiddenFilesShown)
        actions.toggleHiddenFiles()
        actions.toggleHiddenFiles()
        XCTAssertTrue(actions.inFlight.contains(.hidden))
        while !actions.inFlight.isEmpty { await Task.yield() }
        XCTAssertEqual(calls, 1)
        XCTAssertNil(actions.error)
        XCTAssertTrue(actions.hiddenFilesShown)
        actions.emptyTrash()
        while !actions.inFlight.isEmpty { await Task.yield() }
        XCTAssertTrue(actions.hiddenFilesShown)
        actions.toggleHiddenFiles()
        while !actions.inFlight.isEmpty { await Task.yield() }
        XCTAssertFalse(actions.hiddenFilesShown)
    }
    @MainActor func testTrashCancellationIsSilentAndFailuresRemainVisible() async {
        let cases: [(String, Bool, PermissionRecovery?)] = [("return", false, nil), ("error number -128", false, nil), ("error number -1743", true, .automation), ("error number -1712", true, nil), ("error number -10000", true, nil)]
        for (source, expectedError, recovery) in cases {
            let actions = SystemActions(toggleHidden: {}, trash: {
                try NativeFinder.emptyTrash(script: NSAppleScript(source: source)!)
            })
            actions.emptyTrash()
            while !actions.inFlight.isEmpty { await Task.yield() }
            XCTAssertEqual(actions.error != nil, expectedError, source)
            XCTAssertEqual(actions.error?.recovery, recovery, source)
            XCTAssertEqual(actions.error?.action, expectedError ? .trash : nil, source)
        }
    }
    @MainActor func testDuplicateAndFailure() async {
        var calls = 0
        let actions = SystemActions(toggleHidden: { throw ActionError("denied") }, trash: { calls += 1; throw ActionError("cancelled") })
        actions.emptyTrash(); actions.emptyTrash()
        while !actions.inFlight.isEmpty { await Task.yield() }
        XCTAssertEqual(calls, 1); XCTAssertNotNil(actions.error)
        actions.toggleHiddenFiles()
        while !actions.inFlight.isEmpty { await Task.yield() }
        XCTAssertEqual(actions.error?.message, "denied")
        XCTAssertFalse(actions.hiddenFilesShown)
    }
    @MainActor func testSuccessfulRetryClearsOnlyItsOwnFailure() async {
        var denied = true
        let actions = SystemActions(toggleHidden: { if denied { throw ActionError("denied", recovery: .accessibility) } }, trash: {})
        actions.toggleHiddenFiles()
        while !actions.inFlight.isEmpty { await Task.yield() }
        XCTAssertEqual(actions.error, SystemActions.Failure(action: .hidden, message: "denied", recovery: .accessibility))
        XCTAssertFalse(actions.hiddenFilesShown)
        actions.emptyTrash()
        while !actions.inFlight.isEmpty { await Task.yield() }
        XCTAssertNotNil(actions.error)
        denied = false
        actions.toggleHiddenFiles()
        while !actions.inFlight.isEmpty { await Task.yield() }
        XCTAssertNil(actions.error)
        XCTAssertTrue(actions.hiddenFilesShown)
    }
    @MainActor func testInjectedTimingAndErrors() async throws {
        let actions = SystemActions(toggleHidden: {}, trash: {})
        var samples: [[String: Any]] = []
        actions.timing = { action, phase, time in samples.append(["action": action.rawValue, "phase": phase, "seconds": time]) }
        for _ in 0..<101 {
            actions.toggleHiddenFiles()
            while !actions.inFlight.isEmpty { await Task.yield() }
            actions.emptyTrash()
            while !actions.inFlight.isEmpty { await Task.yield() }
        }
        XCTAssertEqual(samples.count, 808)
        let data = try JSONSerialization.data(withJSONObject: samples, options: [.sortedKeys])
        if let output = ProcessInfo.processInfo.environment["MINIMAL_NOTCH_TIMING_OUTPUT"] {
            try data.write(to: URL(fileURLWithPath: output))
        }
        for message in ["permission denied", "timeout", "cancelled"] {
            let failure = SystemActions(toggleHidden: { throw ActionError(message) }, trash: { throw ActionError(message) })
            failure.toggleHiddenFiles()
            while !failure.inFlight.isEmpty { await Task.yield() }
            XCTAssertTrue(failure.error?.message.contains(message) == true)
            failure.emptyTrash()
            while !failure.inFlight.isEmpty { await Task.yield() }
            XCTAssertTrue(failure.error?.message.contains(message) == true)
        }
    }
    @MainActor func testActualSleepOptIn() throws {
        guard ProcessInfo.processInfo.environment["MINIMAL_NOTCH_TEST_SLEEP"] == "1" else {
            throw XCTSkip("Set MINIMAL_NOTCH_TEST_SLEEP=1 to exercise actual IOKit assertions.")
        }
        let actions = SystemActions(toggleHidden: {}, trash: {})
        defer { actions.shutdown() }
        var samples: [[String: Any]] = []
        actions.timing = { action, phase, time in samples.append(["action": action.rawValue, "phase": phase, "seconds": time]) }
        for index in 0..<102 {
            actions.toggleSleep()
            XCTAssertNil(actions.error)
            XCTAssertEqual(actions.sleepPrevented, index.isMultiple(of: 2))
            XCTAssertTrue(actions.inFlight.isEmpty)
        }
        XCTAssertFalse(actions.sleepPrevented)
        actions.shutdown()
        XCTAssertFalse(actions.sleepPrevented)
        XCTAssertEqual(samples.count, 408)
        if let output = ProcessInfo.processInfo.environment["MINIMAL_NOTCH_SLEEP_TIMING_OUTPUT"] {
            let data = try JSONSerialization.data(withJSONObject: samples, options: [.sortedKeys])
            try data.write(to: URL(fileURLWithPath: output))
        }
    }
}
