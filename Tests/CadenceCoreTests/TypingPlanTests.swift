import CadenceCore
import XCTest

private struct RepeatableRandom: RandomNumberGenerator {
    var state: UInt64 = 1

    mutating func next() -> UInt64 {
        state = state &* 2_862_933_555_777_941_757 &+ 3_037_000_493
        return state
    }
}

final class TypingPlanTests: XCTestCase {
    func testTimingBudgetAndExactReplay() {
        var random = RepeatableRandom()
        let input = String(repeating: "Hello World! é 🧪\r\n\t", count: 50)
        let expected = TypingPlan.normalize(input)
        let pace = Pace(wordsPerMinute: 80, correctionPercent: 8)
        let steps = TypingPlan.make(text: input, pace: pace, random: &random)
        XCTAssertEqual(steps.reduce(0) { $0 + $1.delay }, pace.targetDuration(for: expected.count), accuracy: 0.000001)
        var replay = ""
        var corrections = 0
        for step in steps {
            XCTAssertGreaterThan(step.delay, 0)
            switch step.edit {
            case .append(let insertion), .mistake(let insertion):
                replay += insertion
            case .correct(let mistake, let replacement):
                XCTAssertEqual(replay.last.map(String.init), mistake)
                replay.removeLast()
                replay += replacement
                corrections += 1
            }
        }
        XCTAssertGreaterThan(corrections, 0)
        XCTAssertEqual(replay, expected)
    }

    func testDisabledCorrectionsAndEmptyText() {
        var random = RepeatableRandom()
        let pace = Pace(wordsPerMinute: 40, correctionPercent: 0)
        XCTAssertTrue(TypingPlan.make(text: "", pace: pace, random: &random).isEmpty)
        XCTAssertEqual(TypingPlan.make(text: "a🧪", pace: pace, random: &random).map(\.edit),
                       [.append("a"), .append("🧪")])
    }
}
