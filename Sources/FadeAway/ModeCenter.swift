import FadeAwayCore

/// Owns the live mode state. Not persisted: after a restart the Focus decides again.
@MainActor
final class ModeCenter {
    static let shared = ModeCenter()

    private(set) var state = ModeState()
    var onChange: (() -> Void)?

    func applyFocus(_ mode: Mode) { state.applyFocus(mode); onChange?() }
    func pickManual(_ mode: Mode) { state.pickManual(mode); onChange?() }
    func pickAutomatic() { state.pickAutomatic(); onChange?() }
}
