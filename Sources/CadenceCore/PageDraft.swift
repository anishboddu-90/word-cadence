import Foundation

public struct PageDraft: Codable, Equatable, Identifiable, Sendable {
    public let id: Int
    public var text: String
    public var join: Join
    public var overlap: String
    public var notes: [String]

    public enum Join: String, Codable, CaseIterable, Sendable {
        case paragraph, line, space, continuous
        var separator: String {
            switch self {
            case .paragraph: return "\n\n"
            case .line: return "\n"
            case .space: return " "
            case .continuous: return ""
            }
        }
    }

    public init(id: Int, text: String, join: Join = .paragraph, overlap: String = "", notes: [String] = []) {
        self.id = id
        self.text = text
        self.join = join
        self.overlap = overlap
        self.notes = notes
    }
}

public struct PageProposal: Codable, Equatable, Sendable {
    public var pages: [PageDraft]
    public var questions: [String]

    public init(pages: [PageDraft], questions: [String] = []) {
        self.pages = pages
        self.questions = questions
    }

    public func validate(ids: [Int]) throws -> Self {
        guard pages.map(\.id).sorted() == ids.sorted() else { throw PageError.invalidPhotoList }
        return self
    }

    public func assembled() throws -> String {
        var text = ""
        var didAddPage = false
        for page in pages {
            var part = TypingPlan.normalize(page.text)
            if part.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
            if didAddPage {
                let overlap = TypingPlan.normalize(page.overlap)
                if overlap.isEmpty {
                    text += page.join.separator
                } else {
                    guard text.hasSuffix(overlap), part.hasPrefix(overlap) else {
                        throw PageError.invalidOverlap(page.id)
                    }
                    part.removeFirst(overlap.count)
                }
            }
            text += part
            didAddPage = true
        }
        guard didAddPage else { throw PageError.emptyTranscript }
        return text
    }
}

public enum PageError: LocalizedError {
    case invalidPhotoList
    case invalidOverlap(Int)
    case emptyTranscript

    public var errorDescription: String? {
        switch self {
        case .invalidPhotoList: return "ChatGPT did not include each photo exactly once. Try the transcription again."
        case .invalidOverlap(let id): return "Photo \(id) has an overlap that does not match both pages. Edit the overlap or clear it."
        case .emptyTranscript: return "Enter at least one page of transcript before confirming."
        }
    }
}
