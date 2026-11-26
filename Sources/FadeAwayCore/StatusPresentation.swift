/// Text and icon state shown in the menu bar and the menu.
public enum StatusPresentation {
    public static func modeTitle(_ state: ModeState) -> String {
        let title = "Mode: \(state.activeMode.title)"
        switch state.source {
        case .none: return title
        case .focus: return "\(title) (from Focus)"
        case .auto(.fullscreen): return "\(title) (auto: fullscreen)"
        case .auto(.screenSharing): return "\(title) (auto: screen sharing)"
        case .manual: return "\(title) (manual)"
        }
    }

    public static func iconSymbol(manualPause: Bool, mode: Mode) -> String {
        TimeoutResolver.isPaused(manualPause: manualPause, mode: mode) ? "eye" : "eye.slash"
    }

    /// Manual pause takes precedence when both manual pause and Presentation are on.
    public static func accessibilityDescription(manualPause: Bool, mode: Mode) -> String {
        if manualPause { return "FadeAway – paused" }
        if mode == .presentation { return "FadeAway – Presentation mode" }
        return "FadeAway"
    }

    /// Text inside the parentheses after an app name. Neutral shows only the timeout.
    public static func appSuffix(timeoutLabel: String, category: AppCategory) -> String {
        category == .neutral ? timeoutLabel : "\(timeoutLabel) · \(category.title)"
    }
}
