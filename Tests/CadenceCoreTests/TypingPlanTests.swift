import CadenceCore

private struct RepeatableRandom: RandomNumberGenerator {
    var state: UInt64 = 1

    mutating func next() -> UInt64 {
        state = state &* 2_862_933_555_777_941_757 &+ 3_037_000_493
        return state
    }
}

final class TypingPlanTests {
    func testTimingBudgetAndExactReplay() {
        var random = RepeatableRandom()
        let input = String(repeating: "Hello World! é 🧪\r\n\t", count: 50)
        let expected = TypingPlan.normalize(input)
        let pace = Pace(wordsPerMinute: 80, burstWordsPerMinute: 130, correctionPercent: 8)
        let steps = TypingPlan.make(text: input, pace: pace, random: &random)
        checkEqual(steps.reduce(0) { $0 + $1.delay }, pace.targetDuration(for: expected.count), accuracy: 0.000001)
        var replay: [Character] = []
        var pendingIndex: Int?
        var immediateCorrections = 0
        var delayedCorrections = 0
        for step in steps {
            checkGreaterThan(step.delay, 0)
            switch step.edit {
            case .append(let insertion):
                replay.append(contentsOf: insertion)
            case .mistake(let typed, _):
                checkEqual(pendingIndex, nil)
                pendingIndex = replay.count
                replay.append(contentsOf: typed)
            case .correct(let mistake, let replacement):
                guard let index = pendingIndex else {
                    check(false)
                    return
                }
                checkEqual(String(replay[index]), mistake)
                let trailing = replay.count - index - 1
                check((0...3).contains(trailing))
                if trailing == 0 { immediateCorrections += 1 } else { delayedCorrections += 1 }
                replay.replaceSubrange(index...index, with: replacement)
                pendingIndex = nil
            }
        }
        checkGreaterThan(immediateCorrections, 0)
        checkGreaterThan(delayedCorrections, 0)
        checkEqual(pendingIndex, nil)
        checkEqual(String(replay), expected)
    }

    func testDisabledCorrectionsAndEmptyText() {
        var random = RepeatableRandom()
        let pace = Pace(wordsPerMinute: 40, correctionPercent: 0)
        check(TypingPlan.make(text: "", pace: pace, random: &random).isEmpty)
        checkEqual(TypingPlan.make(text: "a🧪", pace: pace, random: &random).map(\.edit),
                       [.append("a"), .append("🧪")])
    }

    func testBurstHasItsOwnAverageWithoutChangingTheRunDuration() {
        var random = RepeatableRandom()
        let pace = Pace(wordsPerMinute: 60, burstWordsPerMinute: 120, correctionPercent: 0)
        let steps = TypingPlan.make(text: "Flow?", pace: pace, random: &random)
        checkEqual(steps[1...3].reduce(0) { $0 + $1.delay }, 0.3, accuracy: 0.000001)
        checkEqual(steps.reduce(0) { $0 + $1.delay }, 1.0, accuracy: 0.000001)
    }

    func testSentenceStartsGenerallyRunFaster() {
        var random = RepeatableRandom()
        let sentence = "Imagination makes everything easier. "
        let text = String(repeating: sentence, count: 100)
        let pace = Pace(wordsPerMinute: 55, correctionPercent: 0)
        let steps = TypingPlan.make(text: text, pace: pace, random: &random)
        var opening: [Double] = []
        var later: [Double] = []
        for (index, character) in text.enumerated() where character.isLetter {
            if index % sentence.count < 8 {
                opening.append(steps[index].delay)
            } else {
                later.append(steps[index].delay)
            }
        }
        checkGreaterThan(later.reduce(0, +) / Double(later.count),
                         opening.reduce(0, +) / Double(opening.count))
    }
}
