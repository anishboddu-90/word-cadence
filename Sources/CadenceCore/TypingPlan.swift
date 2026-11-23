import Foundation

public struct TypingStep: Equatable, Sendable {
    public let delay: Double
    public let edit: TypingEdit
}

public enum TypingEdit: Equatable, Sendable {
    case append(String)
    case mistake(typed: String, intended: String)
    case correct(mistake: String, replacement: String)
}

public enum TypingPlan {
    private static let sentenceEndings = ".?!…"

    public static func normalize(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    public static func make<R: RandomNumberGenerator>(text: String, pace: Pace, random: inout R) -> [TypingStep] {
        let characters = Array(normalize(text))
        let burstPositions = pace.burstInterval == nil ? IndexSet() : bursts(in: characters, random: &random)
        var weightedEdits: [(weight: Double, edit: TypingEdit, burst: Bool)] = []
        var momentum = 1.0
        var previous: Character?
        var sentenceLength = 0
        var sawSentenceEnding = false
        var pending: (index: Int, mistake: String, intended: String)?
        for (index, character) in characters.enumerated() {
            momentum = 0.81 * momentum + 0.19 * Double.random(in: 0.73...1.30, using: &random)
            var weight = momentum * Double.random(in: 0.61...1.42, using: &random)
            if let previous {
                weight *= boundaryWeight(after: previous, before: character)
            }
            if character == "\n" || (sawSentenceEnding && character.isWhitespace) {
                sentenceLength = 0
                sawSentenceEnding = false
            } else if character.isLetter || character.isNumber {
                if sentenceLength < 8 {
                    weight *= 0.78 + Double(sentenceLength) * 0.027
                }
                sentenceLength += 1
                sawSentenceEnding = false
            } else if sentenceEndings.contains(character) {
                sawSentenceEnding = true
            }

            if pending == nil, let mistake = correctedMistake(for: character, pace: pace, random: &random) {
                let intended = String(character)
                let available = characters[(index + 1)...].prefix(3).prefix {
                    $0.isASCII && $0.isLetter
                }.count
                let shouldDelay = available > 0 && Int.random(in: 0..<100, using: &random) < 45
                let skip = shouldDelay ? Int.random(in: 1...available, using: &random) : 0
                pending = (index + skip, mistake, intended)
                weightedEdits.append((weight, .mistake(typed: mistake, intended: intended), false))
            } else {
                weightedEdits.append((weight, .append(String(character)), burstPositions.contains(index)))
            }

            if let correction = pending, correction.index == index {
                let correctionDelay = Double.random(in: 1.4...3.1, using: &random)
                weightedEdits.append((correctionDelay, .correct(mistake: correction.mistake, replacement: correction.intended), false))
                pending = nil
            }
            previous = character
        }

        var burstCount = 0
        var burstWeight = 0.0
        var regularWeight = 0.0
        for step in weightedEdits {
            if step.burst {
                burstCount += 1
                burstWeight += step.weight
            } else {
                regularWeight += step.weight
            }
        }
        guard regularWeight > 0 else { return [] }
        let burstDuration = Double(burstCount) * (pace.burstInterval ?? 0)
        let regularScale = (pace.targetDuration(for: characters.count) - burstDuration) / regularWeight
        let burstScale = burstWeight > 0 ? burstDuration / burstWeight : 0
        return weightedEdits.map { step in
            TypingStep(delay: step.weight * (step.burst ? burstScale : regularScale), edit: step.edit)
        }
    }

    private static func bursts<R: RandomNumberGenerator>(in characters: [Character], random: inout R) -> IndexSet {
        var result = IndexSet()
        var cursor = 0
        var nextBurstAt = 0
        while cursor < characters.count {
            let wordStart = cursor
            while cursor < characters.count, characters[cursor].isLetter || characters[cursor].isNumber {
                cursor += 1
            }
            if cursor == wordStart {
                cursor += 1
                continue
            }

            // Preserve the approach to a word and leave room between bursts.
            let first = max(wordStart + 1, nextBurstAt)
            let available = cursor - first
            guard available >= 3 else { continue }
            let length = Int.random(in: 3...min(7, available), using: &random)
            let start = Int.random(in: first...(cursor - length), using: &random)
            result.insert(integersIn: start..<(start + length))
            nextBurstAt = start + length + Int.random(in: 6...15, using: &random)
        }
        return result
    }

    private static func boundaryWeight(after previous: Character, before character: Character) -> Double {
        if previous == "\n" { return character == "\n" ? 1.5 : 3.6 }
        if sentenceEndings.contains(previous) { return character.isWhitespace ? 2.6 : 1.25 }
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
