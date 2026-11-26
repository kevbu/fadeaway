import CoreGraphics
import XCTest
@testable import FadeAwayCore

final class AutoPresentationDetectorTests: XCTestCase {
    /// Built-in display of the target machine: 1710x1112 with a 37.5 pt camera housing.
    private let main = CGRect(x: 0, y: 0, width: 1710, height: 1112)
    private let mainNotch: CGFloat = 37.5
    private let secondary = CGRect(x: 1710, y: -484, width: 2560, height: 1440)
    /// Native fullscreen window on the notched display: placed below the camera housing.
    private var belowNotch: CGRect { CGRect(x: 0, y: 37.5, width: 1710, height: 1074.5) }

    private var displaySnapshots: [DisplaySnapshot] {
        [DisplaySnapshot(bounds: main, topInset: mainNotch), DisplaySnapshot(bounds: secondary)]
    }

    private func menuBar(on display: CGRect, height: CGFloat) -> WindowSnapshot {
        window(nil, regular: false, layer: 24,
            bounds: CGRect(x: display.minX, y: display.minY, width: display.width, height: height))
    }

    private func window(
        _ bundleID: String? = "com.example.editor", regular: Bool = true,
        layer: Int = 0, alpha: Double = 1, bounds: CGRect
    ) -> WindowSnapshot {
        WindowSnapshot(ownerBundleID: bundleID, ownerIsRegularApp: regular, layer: layer, alpha: alpha, bounds: bounds)
    }

    private func detect(_ windows: [WindowSnapshot], displays: [DisplaySnapshot]? = nil) -> AutoReason? {
        AutoPresentationDetector.detect(windows: windows, displays: displays ?? displaySnapshots)
    }

    func testFullscreenOnMainDisplay() {
        XCTAssertEqual(detect([window(bounds: main)]), .fullscreen)
    }

    func testFullscreenOnSecondaryDisplayWithNegativeOrigin() {
        XCTAssertEqual(detect([window(bounds: secondary)]), .fullscreen)
    }

    func testFullscreenAllowsOnePointTolerance() {
        XCTAssertEqual(detect([window(bounds: main.insetBy(dx: 0.5, dy: 0.5))]), .fullscreen)
    }

    func testBelowNotchFullscreenWithoutMenuBarIsFullscreen() {
        XCTAssertEqual(detect([window(bounds: belowNotch)]), .fullscreen)
    }

    func testZoomedWindowBelowMenuBarOnNotchedDisplayIsNotFullscreen() {
        let windows = [window(bounds: belowNotch), menuBar(on: main, height: 38), menuBar(on: secondary, height: 30)]
        XCTAssertNil(detect(windows))
    }

    func testBelowNotchFrameOnDisplayWithoutNotchIsNotFullscreen() {
        XCTAssertNil(detect([window(bounds: belowNotch)], displays: [DisplaySnapshot(bounds: main)]))
    }

    func testZoomedWindowOnSecondaryDisplayIsNotFullscreen() {
        let zoomed = CGRect(x: 1710, y: -454, width: 2560, height: 1410)
        XCTAssertNil(detect([window(bounds: zoomed)]))
    }

    func testShortWindowBelowNotchIsNotFullscreen() {
        let short = CGRect(x: 0, y: 60, width: 1710, height: 1052)
        XCTAssertNil(detect([window(bounds: short)]))
    }

    func testImplausibleTopInsetIsCapped() {
        let display = DisplaySnapshot(bounds: main, topInset: 300)
        XCTAssertNil(detect([window(bounds: CGRect(x: 0, y: 300, width: 1710, height: 812))], displays: [display]))
    }

    func testFullDisplayWindowIsFullscreenEvenWithMenuBarListed() {
        XCTAssertEqual(detect([window(bounds: secondary), menuBar(on: secondary, height: 30)]), .fullscreen)
    }

    func testMenuBarOnOtherDisplayDoesNotBlockNotchFullscreen() {
        let windows = [window(bounds: belowNotch), menuBar(on: secondary, height: 30)]
        XCTAssertEqual(detect(windows), .fullscreen)
    }

    func testLockScreenWindowsAreIgnored() {
        let windows = [
            window("com.apple.loginwindow", regular: false, layer: 2001, bounds: main),
            window("com.apple.loginwindow", regular: false, layer: 2004, bounds: secondary),
            window(nil, regular: false, layer: 2_147_483_646, bounds: main),
        ]
        XCTAssertNil(detect(windows))
    }

    func testRegularAppAtScreenSaverLevelIsIgnored() {
        XCTAssertNil(detect([window(layer: 1000, bounds: main)]))
    }

    func testNegativeLayerIsIgnored() {
        XCTAssertNil(detect([window(layer: -1, bounds: main)]))
    }

    func testTransparentWindowIsIgnored() {
        XCTAssertNil(detect([window(alpha: 0, bounds: main)]))
    }

    func testEmptyInputs() {
        XCTAssertNil(detect([]))
        XCTAssertNil(detect([window(bounds: main)], displays: []))
    }

    func testTeamsHelperOverlayIsScreenSharing() {
        let overlay = window("com.microsoft.teams2.helper", regular: false, layer: 3, bounds: main)
        XCTAssertEqual(detect([overlay]), .screenSharing)
    }

    func testZoomShareHelperOverlayIsScreenSharing() {
        let overlay = window("us.zoom.CptHost", regular: false, layer: 3, bounds: secondary)
        XCTAssertEqual(detect([overlay]), .screenSharing)
    }

    func testSlackOverlayIsScreenSharing() {
        let overlay = window("com.tinyspeck.slackmacgap", layer: 3, bounds: main.insetBy(dx: 40, dy: 25))
        XCTAssertEqual(detect([overlay]), .screenSharing)
    }

    func testSmallMeetingCallWindowIsNotScreenSharing() {
        let mini = window("com.microsoft.teams2", layer: 3, bounds: CGRect(x: 100, y: 100, width: 300, height: 200))
        XCTAssertNil(detect([mini]))
    }

    func testMeetingAppOverlayAtLayerZeroIsNotScreenSharing() {
        let normal = window("com.microsoft.teams2", regular: false, layer: 0, bounds: main)
        XCTAssertNil(detect([normal]))
    }

    func testUnlistedFloatingOverlayIsNotScreenSharing() {
        XCTAssertNil(detect([window("com.example.overlay", regular: false, layer: 3, bounds: main)]))
        XCTAssertEqual(detect([window("com.example.overlay", regular: true, layer: 3, bounds: main)]), .fullscreen)
    }

    func testScreenSharingWinsOverFullscreen() {
        let windows = [
            window(bounds: main),
            window("com.tinyspeck.slackmacgap", layer: 3, bounds: secondary),
        ]
        XCTAssertEqual(detect(windows), .screenSharing)
    }

    func testCustomSignatureListIsHonoured() {
        let custom = [MeetingAppSignature(name: "Example Meet", bundleIDPrefix: "com.example.meet")]
        let overlay = window("com.example.meet.helper", regular: false, layer: 5, bounds: main)
        XCTAssertEqual(AutoPresentationDetector.detect(
                windows: [overlay], displays: [DisplaySnapshot(bounds: main)], signatures: custom), .screenSharing)
        let teams = window("com.microsoft.teams2", regular: false, layer: 5, bounds: main)
        XCTAssertNil(
            AutoPresentationDetector.detect(windows: [teams], displays: [DisplaySnapshot(bounds: main)], signatures: custom))
    }

    func testSignatureTableHasOneEntryPerApp() {
        XCTAssertEqual(MeetingAppSignature.all.map(\.name), ["Microsoft Teams", "Slack", "Zoom"])
        XCTAssertEqual(
            MeetingAppSignature.all.map(\.bundleIDPrefix), ["com.microsoft.teams", "com.tinyspeck.slackmacgap", "us.zoom."])
    }
}
