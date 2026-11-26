import AppIntents
import FadeAwayCore

/// The modes a Focus Filter can set. No "Normal": having no filter means Normal.
enum ModeOption: String, AppEnum {
    case work, personal, focus, presentation

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Mode"

    static var caseDisplayRepresentations: [ModeOption: DisplayRepresentation] = [
        .work: DisplayRepresentation(title: "Work", subtitle: "Hide personal apps faster"),
        .personal: DisplayRepresentation(title: "Personal", subtitle: "Hide work apps faster"),
        .focus: DisplayRepresentation(title: "Focus", subtitle: "Hide all apps faster"),
        .presentation: DisplayRepresentation(title: "Presentation", subtitle: "Pause hiding"),
    ]

    var mode: Mode {
        switch self {
        case .work: return .work
        case .personal: return .personal
        case .focus: return .focus
        case .presentation: return .presentation
        }
    }
}
