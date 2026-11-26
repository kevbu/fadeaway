import AppIntents
import FadeAwayCore

/// Focus Filter shown in System Settings > Focus. Focus off calls `perform()` with `mode == nil`.
struct FadeAwayFocusFilter: SetFocusFilterIntent {
    static var title: LocalizedStringResource = "FadeAway"

    @Parameter(title: "Mode")
    var mode: ModeOption?

    var displayRepresentation: DisplayRepresentation {
        if let mode {
            return DisplayRepresentation(title: "FadeAway: \(mode.mode.title)")
        }
        return DisplayRepresentation(title: "FadeAway")
    }

    func perform() async throws -> some IntentResult {
        let mode = self.mode?.mode ?? .normal
        await MainActor.run { ModeCenter.shared.applyFocus(mode) }
        return .result()
    }
}
