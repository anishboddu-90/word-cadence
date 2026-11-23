import Foundation

@main
enum Runner {
    static func main() {
        PaceTests().testSpeedAndCorrectionSettingsAreBounded()
        PaceTests().testWPMUsesFiveCharactersPerWord()
        TypingPlanTests().testTimingBudgetAndExactReplay()
        TypingPlanTests().testDisabledCorrectionsAndEmptyText()
        PageChecks.run()
        print("All cadence checks passed.")
    }
}

func check(_ condition: @autoclosure () -> Bool, file: StaticString = #filePath, line: UInt = #line) {
    guard condition() else {
        let message = "Check failed at \(file):\(line)\n"
        FileHandle.standardError.write(Data(message.utf8))
        exit(1)
    }
}

func checkEqual<T: Equatable>(_ actual: T, _ expected: T, file: StaticString = #filePath, line: UInt = #line) {
    check(actual == expected, file: file, line: line)
}

func checkEqual(_ actual: Double, _ expected: Double, accuracy: Double, file: StaticString = #filePath, line: UInt = #line) {
    check(abs(actual - expected) <= accuracy, file: file, line: line)
}

func checkGreaterThan<T: Comparable>(_ actual: T, _ expected: T, file: StaticString = #filePath, line: UInt = #line) {
    check(actual > expected, file: file, line: line)
}
