import SwiftUI

@main
@MainActor
struct WordCadenceApp: App {
    @NSApplicationDelegateAdaptor(AppLifecycle.self) private var lifecycle

    var body: some Scene {
        Window("Word Cadence", id: "main") {
            WorkspaceView(word: lifecycle.word, run: lifecycle.run)
        }
        .defaultSize(width: 930, height: 650)
    }
}

@MainActor
final class AppLifecycle: NSObject, NSApplicationDelegate {
    let word = WordClient()
    lazy var run = WritingRun(word: word)

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard run.phase != .idle else { return .terminateNow }
        run.stop()
        Task {
            while run.phase != .idle { try? await Task.sleep(for: .milliseconds(50)) }
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
