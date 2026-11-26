/// Why FadeAway switched to Presentation by itself.
public enum AutoReason: Equatable, Sendable { case fullscreen, screenSharing }

/// Live mode state with three inputs: manual pick, auto presentation and Focus.
/// Precedence: manual > auto > Focus. The latest action wins: a Focus change
/// and an auto-presentation start both end a manual pick.
public struct ModeState: Equatable, Sendable {
    public enum Source: Equatable, Sendable { case none, focus, auto(AutoReason), manual }

    /// Mode from the Focus Filter. `.normal` when no filter is active.
    public private(set) var focusMode: Mode
    /// Mode picked by hand in the menu. nil = Automatic (auto presentation and Focus).
    public private(set) var manualMode: Mode?
    /// Set while auto presentation is active. nil = no auto signal.
    public private(set) var autoReason: AutoReason?

    public init(focusMode: Mode = .normal, manualMode: Mode? = nil, autoReason: AutoReason? = nil) {
        self.focusMode = focusMode
        self.manualMode = manualMode
        self.autoReason = autoReason
    }

    public var activeMode: Mode { manualMode ?? (autoReason != nil ? .presentation : focusMode) }

    public var source: Source {
        if manualMode != nil { return .manual }
        if let autoReason { return .auto(autoReason) }
        return focusMode != .normal ? .focus : .none
    }

    public mutating func applyFocus(_ mode: Mode) {
        focusMode = mode
        manualMode = nil
    }

    /// An auto-on edge ends a manual pick. A reason change or an auto-off edge keeps it.
    public mutating func applyAuto(_ reason: AutoReason?) {
        if autoReason == nil, reason != nil { manualMode = nil }
        autoReason = reason
    }

    public mutating func pickManual(_ mode: Mode) { manualMode = mode }

    public mutating func pickAutomatic() { manualMode = nil }
}
