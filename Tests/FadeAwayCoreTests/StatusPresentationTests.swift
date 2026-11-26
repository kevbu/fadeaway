import XCTest
@testable import FadeAwayCore

final class StatusPresentationTests: XCTestCase {
    func testModeTitles() {
        var s = ModeState()
        XCTAssertEqual(StatusPresentation.modeTitle(s), "Mode: Normal")
        s.applyFocus(.work)
        XCTAssertEqual(StatusPresentation.modeTitle(s), "Mode: Work (from Focus)")
        s.pickManual(.presentation)
        XCTAssertEqual(StatusPresentation.modeTitle(s), "Mode: Presentation (manual)")
        s.pickManual(.normal)
        XCTAssertEqual(StatusPresentation.modeTitle(s), "Mode: Normal (manual)")
        s.pickAutomatic()
        XCTAssertEqual(StatusPresentation.modeTitle(s), "Mode: Work (from Focus)")
    }

    func testIconSymbol() {
        XCTAssertEqual(StatusPresentation.iconSymbol(manualPause: false, mode: .normal), "eye.slash")
        XCTAssertEqual(StatusPresentation.iconSymbol(manualPause: true, mode: .normal), "eye")
        XCTAssertEqual(StatusPresentation.iconSymbol(manualPause: false, mode: .presentation), "eye")
        XCTAssertEqual(StatusPresentation.iconSymbol(manualPause: true, mode: .presentation), "eye")
        XCTAssertEqual(StatusPresentation.iconSymbol(manualPause: false, mode: .focus), "eye.slash")
    }

    func testAccessibilityDescription() {
        XCTAssertEqual(StatusPresentation.accessibilityDescription(manualPause: false, mode: .normal), "FadeAway")
        XCTAssertEqual(StatusPresentation.accessibilityDescription(manualPause: true, mode: .normal), "FadeAway – paused")
        XCTAssertEqual(
            StatusPresentation.accessibilityDescription(manualPause: false, mode: .presentation),
            "FadeAway – Presentation mode")
        XCTAssertEqual(
            StatusPresentation.accessibilityDescription(manualPause: true, mode: .presentation), "FadeAway – paused")
        XCTAssertEqual(StatusPresentation.accessibilityDescription(manualPause: false, mode: .work), "FadeAway")
    }

    func testAppSuffix() {
        XCTAssertEqual(StatusPresentation.appSuffix(timeoutLabel: "default", category: .personal), "default · Personal")
        XCTAssertEqual(StatusPresentation.appSuffix(timeoutLabel: "1 minute", category: .work), "1 minute · Work")
        XCTAssertEqual(StatusPresentation.appSuffix(timeoutLabel: "default", category: .neutral), "default")
    }
}
