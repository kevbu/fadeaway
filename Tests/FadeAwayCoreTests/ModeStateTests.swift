import XCTest
@testable import FadeAwayCore

final class ModeStateTests: XCTestCase {
    func testInitialState() {
        let s = ModeState()
        XCTAssertEqual(s.focusMode, .normal)
        XCTAssertNil(s.manualMode)
        XCTAssertEqual(s.activeMode, .normal)
        XCTAssertEqual(s.source, .none)
    }

    func testFocusSetsMode() {
        var s = ModeState()
        s.applyFocus(.work)
        XCTAssertEqual(s.activeMode, .work)
        XCTAssertEqual(s.source, .focus)
    }

    func testManualOverridesFocus() {
        var s = ModeState()
        s.applyFocus(.work)
        s.pickManual(.presentation)
        XCTAssertEqual(s.activeMode, .presentation)
        XCTAssertEqual(s.source, .manual)
        XCTAssertEqual(s.focusMode, .work)
    }

    func testFocusChangeEndsManualOverride() {
        var s = ModeState()
        s.applyFocus(.work)
        s.pickManual(.presentation)
        s.applyFocus(.personal)
        XCTAssertNil(s.manualMode)
        XCTAssertEqual(s.activeMode, .personal)
        XCTAssertEqual(s.source, .focus)
    }

    func testAutomaticRestoresFocusMode() {
        var s = ModeState()
        s.applyFocus(.focus)
        s.pickManual(.normal)
        XCTAssertEqual(s.activeMode, .normal)
        XCTAssertEqual(s.source, .manual)
        s.pickAutomatic()
        XCTAssertNil(s.manualMode)
        XCTAssertEqual(s.activeMode, .focus)
    }

    func testFocusOffWhileManualActive() {
        var s = ModeState()
        s.applyFocus(.work)
        s.pickManual(.presentation)
        s.applyFocus(.normal)
        XCTAssertNil(s.manualMode)
        XCTAssertEqual(s.activeMode, .normal)
        XCTAssertEqual(s.source, .none)
    }
}
