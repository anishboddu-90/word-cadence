import CadenceCore

final class PaceTests {
    func testSpeedAndCorrectionSettingsAreBounded() {
        let pace = Pace(wordsPerMinute: 1, correctionPercent: 20)
        checkEqual(pace.wordsPerMinute, 10)
        checkEqual(pace.correctionPercent, 8)
    }

    func testWPMUsesFiveCharactersPerWord() {
        checkEqual(Pace(wordsPerMinute: 60).targetDuration(for: 300), 60)
    }
}
