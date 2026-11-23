import XCTest
import CadenceCore

final class PaceTests: XCTestCase {
    func testSpeedAndCorrectionSettingsAreBounded() {
        let pace = Pace(wordsPerMinute: 1, correctionPercent: 20)
        XCTAssertEqual(pace.wordsPerMinute, 10)
        XCTAssertEqual(pace.correctionPercent, 8)
    }

    func testWPMUsesFiveCharactersPerWord() {
        XCTAssertEqual(Pace(wordsPerMinute: 60).targetDuration(for: 300), 60)
    }
}
