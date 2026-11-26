import CoreGraphics

/// One on-screen window as the detector sees it. Owner data and geometry only, no titles.
public struct WindowSnapshot: Equatable, Sendable {
    public var ownerBundleID: String?
    public var ownerIsRegularApp: Bool
    public var layer: Int
    public var alpha: Double
    /// Global display coordinates, origin top left of the main display, Y down.
    public var bounds: CGRect

    public init(ownerBundleID: String?, ownerIsRegularApp: Bool, layer: Int, alpha: Double, bounds: CGRect) {
        self.ownerBundleID = ownerBundleID
        self.ownerIsRegularApp = ownerIsRegularApp
        self.layer = layer
        self.alpha = alpha
        self.bounds = bounds
    }
}

/// One active display. `topInset` is the height of the camera housing (notch), 0 without one.
public struct DisplaySnapshot: Equatable, Sendable {
    /// Global display coordinates, origin top left of the main display, Y down.
    public var bounds: CGRect
    public var topInset: CGFloat

    public init(bounds: CGRect, topInset: CGFloat = 0) {
        self.bounds = bounds
        self.topInset = topInset
    }
}

/// How a meeting app looks while it shares a whole screen: a floating border overlay
/// that covers the display.
///
/// Unverified heuristic: the signatures could not be observed during a live share.
/// When an app update breaks detection, fix the entry here.
public struct MeetingAppSignature: Sendable {
    public var name: String
    /// Prefix match, so helper processes of the app also match.
    public var bundleIDPrefix: String
    public var minLayer: Int
    public var minDisplayCoverage: Double

    public init(name: String, bundleIDPrefix: String, minLayer: Int = 1, minDisplayCoverage: Double = 0.9) {
        self.name = name
        self.bundleIDPrefix = bundleIDPrefix
        self.minLayer = minLayer
        self.minDisplayCoverage = minDisplayCoverage
    }

    public static let all: [MeetingAppSignature] = [
        MeetingAppSignature(name: "Microsoft Teams", bundleIDPrefix: "com.microsoft.teams"),
        MeetingAppSignature(name: "Slack", bundleIDPrefix: "com.tinyspeck.slackmacgap"),
        MeetingAppSignature(name: "Zoom", bundleIDPrefix: "us.zoom."),
    ]
}

/// Decides from the window list whether a presentation is going on. Screen sharing wins over fullscreen.
public enum AutoPresentationDetector {
    /// Windows at this layer and above (screen saver, lock screen, shields) never count as fullscreen.
    static let maxFullscreenLayer = 999
    static let fullscreenTolerance: CGFloat = 1
    /// `kCGMainMenuWindowLevel`: the system menu bar, one window per display.
    static let menuBarLayer = 24
    /// Upper bound for a camera housing inset, so a bogus inset cannot turn a short window into "fullscreen".
    static let maxTopInset: CGFloat = 40

    public static func detect(
        windows: [WindowSnapshot], displays: [DisplaySnapshot],
        signatures: [MeetingAppSignature] = MeetingAppSignature.all
    ) -> AutoReason? {
        let visible = windows.filter { $0.alpha > 0 }
        let bounds = displays.map(\.bounds)
        if visible.contains(where: { isSharingOverlay($0, displays: bounds, signatures: signatures) }) {
            return .screenSharing
        }
        if visible.contains(where: { isFullscreen($0, displays: displays, windows: visible) }) {
            return .fullscreen
        }
        return nil
    }

    private static func isSharingOverlay(
        _ window: WindowSnapshot, displays: [CGRect], signatures: [MeetingAppSignature]
    ) -> Bool {
        guard let id = window.ownerBundleID else { return false }
        return signatures.contains { signature in
            id.hasPrefix(signature.bundleIDPrefix) && window.layer >= signature.minLayer
                && displays.contains { coverage(of: $0, by: window.bounds) >= signature.minDisplayCoverage }
        }
    }

    /// Fullscreen = the window covers the whole display, or, on a display with a notch, everything below
    /// the camera housing while the display shows no menu bar. A zoomed window has the same below-notch frame,
    /// but its display still shows the menu bar.
    private static func isFullscreen(
        _ window: WindowSnapshot, displays: [DisplaySnapshot], windows: [WindowSnapshot]
    ) -> Bool {
        guard window.ownerIsRegularApp, (0...maxFullscreenLayer).contains(window.layer) else { return false }
        let bounds = window.bounds.insetBy(dx: -fullscreenTolerance, dy: -fullscreenTolerance)
        return displays.contains { display in
            let frame = display.bounds
            if bounds.contains(frame) { return true }
            let inset = min(display.topInset, maxTopInset)
            guard inset > 0 else { return false }
            let belowNotch = CGRect(x: frame.minX, y: frame.minY + inset, width: frame.width, height: frame.height - inset)
            return bounds.contains(belowNotch) && !showsMenuBar(display, windows: windows)
        }
    }

    private static func showsMenuBar(_ display: DisplaySnapshot, windows: [WindowSnapshot]) -> Bool {
        let topStrip = CGRect(x: display.bounds.minX, y: display.bounds.minY, width: display.bounds.width, height: 2)
        return windows.contains { !$0.ownerIsRegularApp && $0.layer == menuBarLayer && $0.bounds.intersects(topStrip) }
    }

    private static func coverage(of display: CGRect, by rect: CGRect) -> Double {
        let area = display.width * display.height
        guard area > 0 else { return 0 }
        let overlap = display.intersection(rect)
        guard !overlap.isNull else { return 0 }
        return Double(overlap.width * overlap.height / area)
    }
}
