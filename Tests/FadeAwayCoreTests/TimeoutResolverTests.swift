import XCTest
@testable import FadeAwayCore

final class TimeoutResolverTests: XCTestCase {
    private func resolve(
        _ mode: Mode, _ category: AppCategory, override: Int? = nil,
        defaultTimeout: Int = 60, fast: Int = 15, manualPause: Bool = false
    ) -> Int {
        TimeoutResolver.effectiveTimeout(
            mode: mode, category: category, override: override,
            defaultTimeout: defaultTimeout, fastTimeout: fast, manualPause: manualPause)
    }

    func testTableCells() {
        // Expected value per (mode, category) with own = 60, fast = 15. 0 = paused.
        let expected: [Mode: [AppCategory: Int]] = [
            .normal: [.work: 60, .personal: 60, .neutral: 60],
            .work: [.work: 60, .personal: 15, .neutral: 60],
            .personal: [.work: 15, .personal: 60, .neutral: 60],
            .focus: [.work: 15, .personal: 15, .neutral: 15],
            .presentation: [.work: 0, .personal: 0, .neutral: 0],
        ]
        for mode in Mode.allCases {
            for category in AppCategory.allCases {
                XCTAssertEqual(resolve(mode, category), expected[mode]![category]!, "\(mode) / \(category)")
            }
        }
    }

    func testOwnWinsWhenFastIsLarger() {
        XCTAssertEqual(resolve(.work, .personal, defaultTimeout: 30, fast: 300), 30)
        XCTAssertEqual(resolve(.focus, .neutral, override: 15, fast: 60), 15)
    }

    func testOverrideReplacesDefault() {
        XCTAssertEqual(resolve(.normal, .work, override: 120), 120)
        XCTAssertEqual(resolve(.normal, .work, override: nil), 60)
        XCTAssertEqual(resolve(.personal, .work, override: 300, fast: 30), 30)
    }

    func testNeverHideInEveryMode() {
        for mode in Mode.allCases {
            for category in AppCategory.allCases {
                XCTAssertEqual(resolve(mode, category, override: 0), 0, "\(mode) / \(category)")
            }
        }
    }

    func testManualPauseInEveryMode() {
        for mode in Mode.allCases {
            XCTAssertEqual(resolve(mode, .personal, manualPause: true), 0, "\(mode)")
            XCTAssertTrue(TimeoutResolver.isPaused(manualPause: true, mode: mode))
        }
    }

    func testPresentationPausesWithoutManualPause() {
        XCTAssertTrue(TimeoutResolver.isPaused(manualPause: false, mode: .presentation))
        XCTAssertEqual(resolve(.presentation, .neutral, manualPause: false), 0)
    }

    func testNotPausedOtherwise() {
        for mode in Mode.allCases where mode != .presentation {
            XCTAssertFalse(TimeoutResolver.isPaused(manualPause: false, mode: mode), "\(mode)")
        }
    }

    func testCategoryFromStoredValue() {
        XCTAssertEqual(AppCategory(stored: "work"), .work)
        XCTAssertEqual(AppCategory(stored: "personal"), .personal)
        XCTAssertEqual(AppCategory(stored: nil), .neutral)
        XCTAssertEqual(AppCategory(stored: "garbage"), .neutral)
    }

    func testTitles() {
        XCTAssertEqual(Mode.allCases.map(\.title), ["Normal", "Work", "Personal", "Focus", "Presentation"])
        XCTAssertEqual(AppCategory.allCases.map(\.title), ["Work", "Personal", "Neutral"])
    }
}
