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

    // MARK: Auto presentation

    func testInitialAutoReasonIsNil() {
        XCTAssertNil(ModeState().autoReason)
    }

    func testAutoSetsPresentation() {
        var s = ModeState()
        s.applyAuto(.fullscreen)
        XCTAssertEqual(s.autoReason, .fullscreen)
        XCTAssertEqual(s.activeMode, .presentation)
        XCTAssertEqual(s.source, .auto(.fullscreen))
    }

    func testAutoBeatsFocusAndAutoOffReturnsToFocus() {
        var s = ModeState()
        s.applyFocus(.work)
        s.applyAuto(.screenSharing)
        XCTAssertEqual(s.activeMode, .presentation)
        XCTAssertEqual(s.source, .auto(.screenSharing))
        s.applyAuto(nil)
        XCTAssertEqual(s.activeMode, .work)
        XCTAssertEqual(s.source, .focus)
    }

    func testAutoOnEdgeClearsManualPick() {
        var s = ModeState()
        s.applyFocus(.personal)
        s.pickManual(.work)
        s.applyAuto(.fullscreen)
        XCTAssertNil(s.manualMode)
        XCTAssertEqual(s.activeMode, .presentation)
        s.applyAuto(nil)
        XCTAssertEqual(s.activeMode, .personal)
    }

    func testManualPickDuringAutoWins() {
        var s = ModeState()
        s.applyAuto(.fullscreen)
        s.pickManual(.focus)
        XCTAssertEqual(s.activeMode, .focus)
        XCTAssertEqual(s.source, .manual)
    }

    func testReasonChangeDuringAutoKeepsManualPick() {
        var s = ModeState()
        s.applyAuto(.fullscreen)
        s.pickManual(.work)
        s.applyAuto(.screenSharing)
        XCTAssertEqual(s.manualMode, .work)
        XCTAssertEqual(s.autoReason, .screenSharing)
        XCTAssertEqual(s.activeMode, .work)
    }

    func testAutoOffKeepsManualPickMadeDuringAuto() {
        var s = ModeState()
        s.applyAuto(.fullscreen)
        s.pickManual(.work)
        s.applyAuto(nil)
        XCTAssertEqual(s.manualMode, .work)
        XCTAssertEqual(s.activeMode, .work)
        XCTAssertEqual(s.source, .manual)
    }

    func testFocusChangeDuringAutoKeepsAutoActive() {
        var s = ModeState()
        s.applyAuto(.fullscreen)
        s.applyFocus(.work)
        XCTAssertEqual(s.activeMode, .presentation)
        XCTAssertEqual(s.source, .auto(.fullscreen))
        XCTAssertEqual(s.focusMode, .work)
    }
}
