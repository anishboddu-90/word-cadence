import Foundation

enum AppFailure: LocalizedError {
    case setup(String)
    case wordResponse

    var errorDescription: String? {
        switch self {
        case .setup(let message): return message
        case .wordResponse: return "Microsoft Word returned an unexpected response."
        }
    }
}
