enum WordWindowMode: String, CaseIterable, Identifiable {
    case visible, minimized, fullScreen

    var id: Self { self }

    var label: String {
        switch self {
        case .visible: return "Visible"
        case .minimized: return "Minimized"
        case .fullScreen: return "Full Screen"
        }
    }

    var detail: String {
        switch self {
        case .visible: return "Brings Word forward and appends at the end."
        case .minimized: return "Appends at the end while the Word window is in the Dock."
        case .fullScreen: return "Opens Word in macOS Full Screen and appends at the end."
        }
    }
}
