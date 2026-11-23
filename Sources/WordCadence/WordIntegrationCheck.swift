#if DEBUG
import AppKit
import Foundation

@MainActor
enum WordIntegrationCheck {
    static func run() throws {
        let client = WordClient()
        _ = try client.documents()
        let prefix = "Existing fixture. " + String(repeating: "🧪", count: 28)
        let fixture = try makeFixture(prefix)
        defer { try? closeFixture(fixture) }

        let startingApplication = NSWorkspace.shared.frontmostApplication?.processIdentifier
        var tail = try client.begin(fixture)
        try check(try snapshot(fixture).1, "Word must minimize the target window.")
        for character in "á🙋🏽‍♂️\nfirst\tline\n" {
            tail = try client.edit(fixture, tail: tail, with: String(character))
        }
        tail = try client.edit(fixture, tail: tail, with: "w")
        tail = try client.edit(fixture, tail: tail, replacing: "w", with: "q")
        tail = try client.edit(fixture, tail: tail, with: "x")
        tail = try client.edit(fixture, tail: tail, replacing: "x", with: "")
        let (actual, minimized) = try snapshot(fixture)
        try check(actual == prefix + "á🙋🏽‍♂️\rfirst\tline\rq\r", "Word content changed unexpectedly.")
        try check(minimized, "The window left its minimized state.")
        if let startingApplication {
            try check(NSWorkspace.shared.frontmostApplication?.processIdentifier == startingApplication,
                      "Writing changed the active application.")
        }

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
        print("Word check passed: exact Unicode text, typo replacement/removal, minimized state, stable focus, and document-change guards.")
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

    private static func snapshot(_ fixture: WordDocument) throws -> (String, Bool) {
        let result = try execute("read fixture", """
        set fixture to document \(literal(fixture.name))
        if (full name of fixture as text) is not \(literal(fixture.path)) then error "Fixture changed."
        return {(content of text object of fixture as text), (window state of active window of fixture is window state minimize)}
        """)
        guard let text = result.atIndex(1)?.stringValue, let minimized = result.atIndex(2)?.booleanValue else {
            throw AppFailure.wordResponse
        }
        return (text, minimized)
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
