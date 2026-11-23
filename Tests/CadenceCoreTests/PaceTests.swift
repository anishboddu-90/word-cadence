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

    func testBurstSpeedIsOptionalAndFasterThanAverage() {
        checkEqual(Pace().burstWordsPerMinute, nil)
        checkEqual(Pace(wordsPerMinute: 155, burstWordsPerMinute: 90).burstWordsPerMinute, 156)
        checkEqual(Pace(burstWordsPerMinute: 999).burstWordsPerMinute, 240)
    }
}
