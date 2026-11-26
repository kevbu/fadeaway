/// Decides how long an app may stay in the background. 0 means "do not hide".
public enum TimeoutResolver {
    /// Hiding is paused by the manual "Pause hiding" switch or by Presentation mode.
    public static func isPaused(manualPause: Bool, mode: Mode) -> Bool {
        manualPause || mode == .presentation
    }

    public static func effectiveTimeout(
        mode: Mode, category: AppCategory, override: Int?,
        defaultTimeout: Int, fastTimeout: Int, manualPause: Bool
    ) -> Int {
        if isPaused(manualPause: manualPause, mode: mode) { return 0 }
        let own = override ?? defaultTimeout
        if own == 0 { return 0 }
        return usesFastTimeout(mode: mode, category: category) ? min(own, fastTimeout) : own
    }

    private static func usesFastTimeout(mode: Mode, category: AppCategory) -> Bool {
        switch mode {
        case .normal, .presentation: return false
        case .work: return category == .personal
        case .personal: return category == .work
        case .focus: return true
        }
    }
}
