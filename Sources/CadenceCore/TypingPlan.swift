import Foundation

public struct TypingStep: Equatable, Sendable {
    public let delay: Double
    public let edit: TypingEdit
}

public enum TypingEdit: Equatable, Sendable {
    case append(String)
    case mistake(String)
    case correct(mistake: String, replacement: String)
}

public enum TypingPlan {
    public static func normalize(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    public static func make<R: RandomNumberGenerator>(text: String, pace: Pace, random: inout R) -> [TypingStep] {
        let characters = Array(normalize(text))
        var weightedEdits: [(weight: Double, edit: TypingEdit)] = []
        var momentum = 1.0
        var previous: Character?
        for character in characters {
            momentum = 0.81 * momentum + 0.19 * Double.random(in: 0.73...1.30, using: &random)
            var weight = momentum * Double.random(in: 0.61...1.42, using: &random)
            if let previous {
                weight *= boundaryWeight(after: previous, before: character)
            }

            if let mistake = correctedMistake(for: character, pace: pace, random: &random) {
                weightedEdits.append((weight, .mistake(mistake)))
                let correctionDelay = Double.random(in: 1.4...3.1, using: &random)
                weightedEdits.append((correctionDelay, .correct(mistake: mistake, replacement: String(character))))
            } else {
                weightedEdits.append((weight, .append(String(character))))
            }
            previous = character
        }
        let total = weightedEdits.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return [] }
        let scale = pace.targetDuration(for: characters.count) / total
        return weightedEdits.map { TypingStep(delay: $0.weight * scale, edit: $0.edit) }
    }

    private static func boundaryWeight(after previous: Character, before character: Character) -> Double {
        if previous == "\n" { return 3.6 }
        if ".?!".contains(previous) { return character.isWhitespace ? 2.6 : 1.25 }
        if ",;:".contains(previous) && character.isWhitespace { return 1.7 }
        if previous.isWhitespace { return 1.22 }
        return 1
    }

    private static let rows = [Array("qwertyuiop"), Array("asdfghjkl"), Array("zxcvbnm")]

    private static func correctedMistake<R: RandomNumberGenerator>(
        for character: Character, pace: Pace, random: inout R
    ) -> String? {
        guard pace.correctionPercent > 0,
              Int.random(in: 0..<100, using: &random) < pace.correctionPercent,
              character.isASCII,
              let key = character.lowercased().first else { return nil }
        for row in rows {
            guard let index = row.firstIndex(of: key) else { continue }
            let neighbors = [index - 1, index + 1].filter { row.indices.contains($0) }
            guard let neighbor = neighbors.randomElement(using: &random) else { return nil }
            return character.isUppercase ? row[neighbor].uppercased() : String(row[neighbor])
        }
        return nil
    }
}
