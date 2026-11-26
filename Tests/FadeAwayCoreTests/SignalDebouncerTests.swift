import XCTest
@testable import FadeAwayCore

final class SignalDebouncerTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 1000)
    private func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    private func onDebouncer() -> SignalDebouncer {
        var d = SignalDebouncer()
        _ = d.update(raw: .fullscreen, now: at(0))
        _ = d.update(raw: .fullscreen, now: at(2))
        return d
    }

    func testInitialOutputIsNil() {
        XCTAssertNil(SignalDebouncer().output)
    }

    func testTurnsOnAfterOnDelay() {
        var d = SignalDebouncer()
        XCTAssertNil(d.update(raw: .fullscreen, now: at(0)))
        XCTAssertNil(d.update(raw: .fullscreen, now: at(1.9)))
        XCTAssertEqual(d.update(raw: .fullscreen, now: at(2)), .fullscreen)
        XCTAssertEqual(d.output, .fullscreen)
    }

    func testReasonChangeDoesNotRestartOnTimer() {
        var d = SignalDebouncer()
        _ = d.update(raw: .fullscreen, now: at(0))
        XCTAssertNil(d.update(raw: .screenSharing, now: at(1)))
        XCTAssertEqual(d.update(raw: .screenSharing, now: at(2)), .screenSharing)
    }

    func testTurnsOffAfterOffDelay() {
        var d = onDebouncer()
        XCTAssertEqual(d.update(raw: nil, now: at(3)), .fullscreen)
        XCTAssertEqual(d.update(raw: nil, now: at(7.9)), .fullscreen)
        XCTAssertNil(d.update(raw: nil, now: at(8)))
    }

    func testShortGapWhileOnKeepsOn() {
        var d = onDebouncer()
        _ = d.update(raw: nil, now: at(3))
        _ = d.update(raw: nil, now: at(6))
        XCTAssertEqual(d.update(raw: .fullscreen, now: at(7)), .fullscreen)
        XCTAssertEqual(d.update(raw: nil, now: at(8)), .fullscreen)
        XCTAssertEqual(d.update(raw: nil, now: at(12)), .fullscreen)
        XCTAssertNil(d.update(raw: nil, now: at(13)))
    }

    func testShortSignalWhileOffDoesNotTurnOn() {
        var d = SignalDebouncer()
        _ = d.update(raw: .fullscreen, now: at(0))
        _ = d.update(raw: .fullscreen, now: at(1))
        XCTAssertNil(d.update(raw: nil, now: at(1.5)))
        XCTAssertNil(d.update(raw: .fullscreen, now: at(2)))
        XCTAssertNil(d.update(raw: .fullscreen, now: at(3.9)))
        XCTAssertEqual(d.update(raw: .fullscreen, now: at(4)), .fullscreen)
    }

    func testReasonSwitchWhileOnIsImmediate() {
        var d = onDebouncer()
        XCTAssertEqual(d.update(raw: .screenSharing, now: at(3)), .screenSharing)
        XCTAssertEqual(d.update(raw: .fullscreen, now: at(4)), .fullscreen)
    }

    func testLastReasonStaysDuringOffDelay() {
        var d = onDebouncer()
        _ = d.update(raw: .screenSharing, now: at(3))
        XCTAssertEqual(d.update(raw: nil, now: at(4)), .screenSharing)
    }

    func testResetClearsState() {
        var d = onDebouncer()
        d.reset()
        XCTAssertNil(d.output)
        XCTAssertNil(d.update(raw: .fullscreen, now: at(10)))
        XCTAssertNil(d.update(raw: .fullscreen, now: at(11)))
        XCTAssertEqual(d.update(raw: .fullscreen, now: at(12)), .fullscreen)
    }
}
