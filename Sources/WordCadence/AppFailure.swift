import Foundation

enum AppFailure: LocalizedError {
    case setup(String)
    case wordResponse
    case wordMinimize

    var errorDescription: String? {
        switch self {
        case .setup(let message): return message
        case .wordResponse: return "Microsoft Word returned an unexpected response."
        case .wordMinimize: return "Word could not minimize the selected window. Exit Full Screen in Word, then try again."
        }
    }
}
