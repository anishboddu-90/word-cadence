import CadenceCore
import Foundation

@MainActor
final class WritingRun: ObservableObject {
    enum Phase { case idle, writing, paused, stopping }

    @Published private(set) var phase = Phase.idle
    @Published private(set) var completed = 0
    @Published private(set) var total = 0
    @Published private(set) var message = "Open a document in Microsoft Word to get started."

    private let word: WordClient
    private var task: Task<Void, Never>?

    init(word: WordClient) {
        self.word = word
    }

    func start(text: String, pace: Pace, document: WordDocument, mode: WordWindowMode) {
        guard phase == .idle else { return }
        let text = TypingPlan.normalize(text)
        guard !text.isEmpty else { return }
        guard !text.unicodeScalars.contains(where: { $0.value < 32 && $0.value != 9 && $0.value != 10 }) else {
            message = "Remove unsupported control characters before starting."
            return
        }
        completed = 0
        total = text.count
        phase = .writing
        message = "Preparing \(document.name)…"
        task = Task { await execute(text: text, pace: pace, document: document, mode: mode) }
    }

    func togglePause() {
        if phase == .writing {
            phase = .paused
            message = "Paused"
        } else if phase == .paused {
            phase = .writing
            message = "Writing…"
        }
    }

    func stop() {
        guard phase == .writing || phase == .paused else { return }
        phase = .stopping
        task?.cancel()
    }

    private func execute(text: String, pace: Pace, document: WordDocument, mode: WordWindowMode) async {
        defer {
            phase = .idle
            task = nil
        }

        var tail: WordTail?
        var pendingMistake: String?
        let clock = ContinuousClock()
        do {
            try Task.checkCancellation()
            tail = try await word.begin(document, mode: mode)
            var random = SystemRandomNumberGenerator()
            let plan = TypingPlan.make(text: text, pace: pace, random: &random)
            if phase == .writing { message = "Writing to \(document.name)…" }
            var deadline = clock.now

            for step in plan {
                // Absorb small Apple-event delays without racing to catch up after a slowdown.
                deadline = max(deadline, clock.now - .milliseconds(70)) + .seconds(step.delay)
                try await clock.sleep(until: deadline)
                if phase == .paused && pendingMistake == nil {
                    let pausedAt = clock.now
                    while phase == .paused {
                        try await Task.sleep(for: .milliseconds(50))
                    }
                    deadline += pausedAt.duration(to: clock.now)
                }
                try Task.checkCancellation()
                guard let current = tail else { throw AppFailure.wordResponse }
                switch step.edit {
                case .append(let character):
                    tail = try word.edit(document, tail: current, with: character)
                    completed += 1
                case .mistake(let character):
                    tail = try word.edit(document, tail: current, with: character)
                    pendingMistake = character
                case .correct(let mistake, let character):
                    tail = try word.edit(document, tail: current, replacing: mistake, with: character)
                    pendingMistake = nil
                    completed += 1
                }
            }
            message = "Finished writing \(completed.formatted()) characters to \(document.name)."
        } catch {
            if let tail, let pendingMistake {
                do {
                    _ = try word.edit(document, tail: tail, replacing: pendingMistake, with: "")
                } catch {
                    message = "Stopped after \(completed.formatted()) characters. Check the end of the document for a pending typo. \(error.localizedDescription)"
                    return
                }
            }
            if error is CancellationError {
                message = "Stopped after \(completed.formatted()) of \(total.formatted()) characters."
            } else {
                message = "Stopped after \(completed.formatted()) characters. \(error.localizedDescription)"
            }
        }
    }
}
