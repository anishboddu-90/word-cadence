public struct Pace: Equatable, Sendable {
    public static let speedRange = 10...180
    public static let correctionRange = 0...8

    public let wordsPerMinute: Int
    public let correctionPercent: Int

    public init(wordsPerMinute: Int = 55, correctionPercent: Int = 2) {
        self.wordsPerMinute = min(Self.speedRange.upperBound, max(Self.speedRange.lowerBound, wordsPerMinute))
        self.correctionPercent = min(Self.correctionRange.upperBound, max(0, correctionPercent))
    }

    public func targetDuration(for characterCount: Int) -> Double {
        Double(characterCount) * 60 / (5 * Double(wordsPerMinute))
    }
}
