#if DEBUG
import AppKit
import Foundation

@MainActor
enum WordIntegrationCheck {
    static func run() async throws {
        let client = WordClient()
        _ = try client.documents()
        let prefix = "Existing fixture. " + String(repeating: "🧪", count: 28)
        let fixture = try makeFixture(prefix)
        defer { try? closeFixture(fixture) }

        var tail = try await client.begin(fixture, mode: .visible)
        let opened = try snapshot(fixture)
        try check(!opened.minimized && opened.isActive, "Word must show and activate the selected window.")
        for character in "á🙋🏽‍♂️\nfirst\tline\n" {
            tail = try client.edit(fixture, tail: tail, with: String(character))
        }
        tail = try client.edit(fixture, tail: tail, with: "w")
        tail = try client.edit(fixture, tail: tail, replacing: "w", with: "q")
        tail = try client.edit(fixture, tail: tail, with: "x")
        tail = try client.edit(fixture, tail: tail, replacing: "x", with: "")
        let (actual, minimized, _) = try snapshot(fixture)
        try check(actual == prefix + "á🙋🏽‍♂️\rfirst\tline\rq\r", "Word content changed unexpectedly.")
        try check(!minimized, "The writing run minimized the window.")

        let stale = tail
        _ = try client.edit(fixture, tail: tail, with: "!")
        do {
            _ = try client.edit(fixture, tail: stale, with: "Cannot write with stale tail")
            throw AppFailure.setup("The stale document guard failed.")
        } catch {
            try check(error.localizedDescription.contains("changed during writing"), "Wrong stale-edit error: \(error.localizedDescription)")
        }
        try closeFixture(fixture)
        do {
            _ = try client.edit(fixture, tail: tail, with: "Cannot write to a closed document")
            throw AppFailure.setup("The closed document guard failed.")
        } catch {
            try check(error.localizedDescription.contains("closed or renamed"), "Wrong closed-document error: \(error.localizedDescription)")
        }
        try await checkTrackedEdits(using: client, locked: false)
        try await checkTrackedEdits(using: client, locked: true)
        try await checkWindowModes(using: client)
        print("Word check passed: window modes, exact Unicode text, tracked corrections, and document-change guards.")
    }

    private static func checkWindowModes(using client: WordClient) async throws {
        let fixture = try makeFixture("Window mode fixture. ")
        defer { try? closeFixture(fixture) }
        var expected = "Window mode fixture. "
        if WordWindowAccess.isTrusted {
            let fullScreen = try await client.begin(fixture, mode: .fullScreen)
            _ = try client.edit(fixture, tail: fullScreen, with: "Full screen. ")
            expected += "Full screen. "
        } else {
            print("Skipped Full Screen transition. Grant Accessibility to the test runner to cover it.")
        }
        let minimized = try await client.begin(fixture, mode: .minimized)
        _ = try client.edit(fixture, tail: minimized, with: "Minimized.")
        let afterWriting = try snapshot(fixture)
        try check(afterWriting.minimized, "Word did not stay minimized while writing.")
        try check(afterWriting.text == expected + "Minimized.\r", "Window mode changed the document text.")
        _ = try await client.begin(fixture, mode: .visible)
        let restored = try snapshot(fixture)
        try check(!restored.minimized && restored.isActive, "Visible mode did not restore the Word window.")
    }

    private static func checkTrackedEdits(using client: WordClient, locked: Bool) async throws {
        let fixture = try makeFixture("Existing draft X")
        defer { try? closeFixture(fixture) }
        _ = try execute("prepare tracked changes", """
        set fixture to document \(literal(fixture.name))
        set track revisions of fixture to true
        set deleteRange to create range fixture start 15 end 16
        set content of deleteRange to ""
        \(locked ? "protect fixture protection type allow only revisions" : "")
        """)

        var tail = try await client.begin(fixture, mode: .visible)
        tail = try client.edit(fixture, tail: tail, with: "w")
        tail = try client.edit(fixture, tail: tail, replacing: "w", with: "q")
        tail = try client.edit(fixture, tail: tail, with: "z")
        _ = try client.edit(fixture, tail: tail, replacing: "z", with: "")

        let result = try execute("check retained revisions", """
        set fixture to document \(literal(fixture.name))
        set insertedText to ""
        set deletedText to ""
        repeat with trackedEdit in (get revisions of fixture)
            set changedText to content of text object of trackedEdit as text
            if revision type of trackedEdit is revision insert then set insertedText to insertedText & changedText
            if revision type of trackedEdit is revision delete then set deletedText to deletedText & changedText
        end repeat
        return {(track revisions of fixture), insertedText, deletedText, (content of text object of fixture as text), (protection type of fixture is allow only revisions)}
        """)
        try check(result.atIndex(1)?.booleanValue == true, "Track Changes was turned off.")
        try check(result.atIndex(2)?.stringValue == "q", "Word did not retain the intended tracked insertion.")
        try check(result.atIndex(3)?.stringValue == "X", "Word changed an existing tracked deletion.")
        try check(result.atIndex(4)?.stringValue == "Existing draft q\r", "The corrected text is wrong with Track Changes enabled.")
        try check(result.atIndex(5)?.booleanValue == locked, "Word changed the document's editing restrictions.")
    }

    private static func makeFixture(_ text: String) throws -> WordDocument {
        let result = try execute("create fixture", """
        set fixture to make new document
        set firstRange to create range fixture start 0 end 0
        set content of firstRange to \(literal(text))
        return {(name of fixture as text), (full name of fixture as text)}
        """)
        guard let name = result.atIndex(1)?.stringValue, let path = result.atIndex(2)?.stringValue else {
            throw AppFailure.wordResponse
        }
        return WordDocument(name: name, path: path)
    }

    private static func snapshot(_ fixture: WordDocument) throws -> (text: String, minimized: Bool, isActive: Bool) {
        let result = try execute("read fixture", """
        set fixture to document \(literal(fixture.name))
        if (full name of fixture as text) is not \(literal(fixture.path)) then error "Fixture changed."
        set isSelected to ((name of active document as text) is (name of fixture as text)) and ((full name of active document as text) is (full name of fixture as text))
        return {(content of text object of fixture as text), (window state of active window of fixture is window state minimize), isSelected}
        """)
        guard let text = result.atIndex(1)?.stringValue, let minimized = result.atIndex(2)?.booleanValue,
              let isActive = result.atIndex(3)?.booleanValue else {
            throw AppFailure.wordResponse
        }
        return (text, minimized, isActive)
    }

    private static func closeFixture(_ fixture: WordDocument) throws {
        _ = try execute("close fixture", """
        if exists document \(literal(fixture.name)) then
            set fixture to document \(literal(fixture.name))
            if (full name of fixture as text) is \(literal(fixture.path)) then close fixture saving no
        end if
        """)
    }

    private static func execute(_ operation: String, _ code: String) throws -> NSAppleEventDescriptor {
        let script = NSAppleScript(source: """
        with timeout of 12 seconds
            tell application id "com.microsoft.Word"
                \(code)
            end tell
        end timeout
        """)
        var error: NSDictionary?
        let result = script?.executeAndReturnError(&error)
        guard error == nil, let result else {
            let detail = error?[NSAppleScript.errorMessage] as? String ?? "Word returned no script response."
            throw AppFailure.setup("Could not \(operation). \(detail)")
        }
        return result
    }

    private static func literal(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    private static func check(_ condition: Bool, _ message: String) throws {
        if !condition { throw AppFailure.setup(message) }
    }
}
#endif
