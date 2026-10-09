import XCTest
import CoreGraphics
@testable import MiniNotch

final class PanelStateTests: XCTestCase {
    func testPinnedPanelStaysVisibleUntilUnpinned() {
        var panel = PanelState()
        panel.pinned = true
        XCTAssertTrue(panel.visible)
        panel.enter(); panel.exit(); panel.expire(); panel.escape()
        XCTAssertTrue(panel.visible)
        panel.pinned = false
        XCTAssertFalse(panel.visible)
    }
    func testPreviewKeepsPanelVisibleWithoutChangingPin() {
        var panel = PanelState()
        panel.previewing = true
        panel.enter(); panel.exit(); panel.expire(); panel.escape()
        XCTAssertTrue(panel.visible)
        XCTAssertFalse(panel.pinned)
        panel.previewing = false
        XCTAssertFalse(panel.visible)
        panel.pinned = true; panel.previewing = true; panel.previewing = false
        XCTAssertTrue(panel.visible)
    }
    func testVisibility() {
        var panel = PanelState()
        panel.enter(); panel.exit(); panel.enter(); panel.expire()
        XCTAssertTrue(panel.visible)
        panel.exit(); panel.expire()
        XCTAssertFalse(panel.visible)
        panel.showKeyboard(); panel.exit(); panel.expire()
        XCTAssertTrue(panel.visible)
        panel.escape(); XCTAssertFalse(panel.visible)
        panel.enter(); panel.hold = true; panel.exit(); panel.expire()
        XCTAssertTrue(panel.visible)
        panel.hold = false; panel.expire(); XCTAssertFalse(panel.visible)
    }
    func testWholeNotchPointerRegion() {
        let notch = CGRect(x: 700, y: 970, width: 160, height: 30)
        let panel = CGRect(x: 648, y: 845, width: 264, height: 125)
        for point in [CGPoint(x: 780, y: 1000), CGPoint(x: 700, y: 985), CGPoint(x: 860, y: 985), CGPoint(x: 780, y: 970)] {
            XCTAssertTrue(pointerInsideActions(point, notch: notch, panel: panel, panelVisible: false))
        }
        XCTAssertFalse(pointerInsideActions(CGPoint(x: 699, y: 985), notch: notch, panel: panel, panelVisible: true))
        XCTAssertFalse(pointerInsideActions(CGPoint(x: 861, y: 985), notch: notch, panel: panel, panelVisible: true))
        XCTAssertTrue(pointerInsideActions(CGPoint(x: 780, y: 969), notch: notch, panel: panel, panelVisible: true))
        XCTAssertTrue(pointerInsideActions(CGPoint(x: 650, y: 900), notch: notch, panel: panel, panelVisible: true))
        XCTAssertFalse(pointerInsideActions(CGPoint(x: 650, y: 900), notch: notch, panel: panel, panelVisible: false))
        XCTAssertFalse(pointerInsideActions(CGPoint(x: 780, y: 844), notch: notch, panel: panel, panelVisible: true))
        XCTAssertFalse(pointerInsideActions(CGPoint(x: 780, y: 1000), notch: nil, panel: panel, panelVisible: false))
    }
}
