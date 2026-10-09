import XCTest
@testable import MiniNotch

final class GlassSettingsTests: XCTestCase {
    func testGlassTintDefaultsAndTileScaling() {
        XCTAssertTrue(GlassTint.range.contains(GlassTint.defaultValue))
        XCTAssertEqual(GlassTint.tile(for: 0.3), 0.2, accuracy: 0.0001)
        XCTAssertEqual(GlassTint.tile(for: 0), 0)
    }
}
