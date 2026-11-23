import Foundation

public struct ResponseStream {
    private var fragments: [String] = []
    public private(set) var isComplete = false

    public init() {}

    public mutating func consume(_ line: String) throws {
        guard line.hasPrefix("data:") else { return }
        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
        guard !payload.isEmpty, payload != "[DONE]" else { return }
        let event = try JSONDecoder().decode(Event.self, from: Data(payload.utf8))
        switch event.type {
        case "response.output_text.delta": fragments.append(event.delta ?? "")
        case "response.completed": isComplete = true
        case "response.failed", "response.incomplete", "error":
            throw ResponseError.failed(event.response?.error?.code ?? event.code)
        case "response.refusal.delta", "response.refusal.done":
            throw ResponseError.refused
        default: break
        }
    }

    public func result() throws -> String {
        guard isComplete else { throw ResponseError.interrupted }
        let text = fragments.joined()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ResponseError.empty }
        return text
    }

    private struct Event: Decodable {
        let type: String
        let delta: String?
        let code: String?
        let response: FailedResponse?
    }

    private struct FailedResponse: Decodable {
        struct Failure: Decodable { let code: String? }
        let error: Failure?
    }
}

public enum ResponseError: LocalizedError {
    case failed(String?)
    case refused
    case interrupted
    case empty

    public var errorDescription: String? {
        switch self {
        case .failed(let code):
            if code?.hasPrefix("subscription_sharing_usage") == true {
                return "ChatGPT plan usage is unavailable or at its limit. Check ChatGPT Settings → Usage."
            }
            return "ChatGPT could not complete the transcription" + (code.map { " (\($0))." } ?? ".")
        case .refused: return "ChatGPT declined to transcribe these photos."
        case .interrupted: return "The ChatGPT response ended early. Try again."
        case .empty: return "ChatGPT returned an empty transcription."
        }
    }
}
