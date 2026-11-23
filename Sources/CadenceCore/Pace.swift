public struct Pace: Equatable, Sendable {
    public static let speedRange = 10...180
    public static let maximumBurstWPM = 240
    public static let correctionRange = 0...8

    public let wordsPerMinute: Int
    public let burstWordsPerMinute: Int?
    public let correctionPercent: Int

    public init(wordsPerMinute: Int = 55, burstWordsPerMinute: Int? = nil, correctionPercent: Int = 2) {
        let average = min(Self.speedRange.upperBound, max(Self.speedRange.lowerBound, wordsPerMinute))
        self.wordsPerMinute = average
        self.burstWordsPerMinute = burstWordsPerMinute.map { min(Self.maximumBurstWPM, max(average + 1, $0)) }
        self.correctionPercent = min(Self.correctionRange.upperBound, max(0, correctionPercent))
    }

    var burstInterval: Double? {
        burstWordsPerMinute.map { 60 / (5 * Double($0)) }
    }

    public func targetDuration(for characterCount: Int) -> Double {
        Double(characterCount) * 60 / (5 * Double(wordsPerMinute))
    }
}
