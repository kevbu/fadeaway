/// Live mode state. The latest action wins: a Focus change ends a manual pick.
public struct ModeState: Equatable, Sendable {
    public enum Source: Equatable, Sendable { case none, focus, manual }

    /// Mode from the Focus Filter. `.normal` when no filter is active.
    public private(set) var focusMode: Mode
    /// Mode picked by hand in the menu. nil = follow the Focus (Automatic).
    public private(set) var manualMode: Mode?

    public init(focusMode: Mode = .normal, manualMode: Mode? = nil) {
        self.focusMode = focusMode
        self.manualMode = manualMode
    }

    public var activeMode: Mode { manualMode ?? focusMode }

    public var source: Source {
        if manualMode != nil { return .manual }
        return focusMode != .normal ? .focus : .none
    }

    public mutating func applyFocus(_ mode: Mode) {
        focusMode = mode
        manualMode = nil
    }

    public mutating func pickManual(_ mode: Mode) { manualMode = mode }

    public mutating func pickAutomatic() { manualMode = nil }
}
