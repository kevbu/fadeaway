/// The hiding mode. Set by a Focus Filter or picked by hand in the menu.
public enum Mode: String, CaseIterable, Sendable {
    case normal, work, personal, focus, presentation

    public var title: String {
        switch self {
        case .normal: return "Normal"
        case .work: return "Work"
        case .personal: return "Personal"
        case .focus: return "Focus"
        case .presentation: return "Presentation"
        }
    }
}

/// The category of an app. Decides which mode hides it faster.
public enum AppCategory: String, CaseIterable, Sendable {
    case work, personal, neutral

    /// Unknown or missing stored values map to `.neutral`.
    public init(stored: String?) {
        self = stored.flatMap(AppCategory.init(rawValue:)) ?? .neutral
    }

    public var title: String {
        switch self {
        case .work: return "Work"
        case .personal: return "Personal"
        case .neutral: return "Neutral"
        }
    }
}
