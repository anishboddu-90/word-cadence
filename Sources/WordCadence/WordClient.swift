import AppKit
import CoreServices

struct WordDocument: Identifiable, Hashable {
    let name: String
    let path: String
    var id: Self { self }
}

struct WordTail {
    let position: Int32
    let text: String
}

@MainActor
final class WordClient {
    private let script = NSAppleScript(source: WordScript.source)
    private let bundleIdentifier = "com.microsoft.Word"

    func checkPermission(prompt: Bool) async throws {
        let bundleIdentifier = self.bundleIdentifier
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty else {
            throw AppFailure.setup("Open Microsoft Word and the document you want to write to.")
        }
        let status = await Task.detached(priority: .userInitiated) {
            let target = NSAppleEventDescriptor(bundleIdentifier: bundleIdentifier)
            return AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, prompt)
        }.value
        switch status {
        case noErr:
            return
        case Int32(errAEEventWouldRequireUserConsent):
            throw AppFailure.setup("Click Refresh to grant Word Cadence permission to control Microsoft Word.")
        case Int32(errAEEventNotPermitted):
            throw AppFailure.setup(Self.permissionInstructions)
        default:
            throw AppFailure.setup("Could not check Microsoft Word access (\(status)). Open Word and click Refresh.")
        }
    }

    func documents() throws -> [WordDocument] {
        let result = try call("list")
        return try (0..<result.numberOfItems).map { offset in
            guard let item = result.atIndex(offset + 1),
                  let name = item.atIndex(1)?.stringValue,
                  let path = item.atIndex(2)?.stringValue else { throw AppFailure.wordResponse }
            return WordDocument(name: name, path: path)
        }
    }

    func begin(_ document: WordDocument, mode: WordWindowMode) async throws -> WordTail {
        if mode == .fullScreen { try WordWindowAccess.requireAccessibility() }
        do {
            let result = try beginWord(document, minimized: mode == .minimized)
            if mode == .fullScreen {
                try await changeFullScreen(true, start: result)
            }
            return try readTail(result)
        } catch AppFailure.wordMinimize where WordWindowAccess.isTrusted {
            let visible = try beginWord(document, minimized: false)
            try await changeFullScreen(false, start: visible)
            return try readTail(beginWord(document, minimized: true))
        }
    }

    private func beginWord(_ document: WordDocument, minimized: Bool) throws -> NSAppleEventDescriptor {
        try call("start", arguments: identity(document) + [NSAppleEventDescriptor(boolean: minimized)])
    }

    private func changeFullScreen(_ enabled: Bool, start: NSAppleEventDescriptor) async throws {
        guard let caption = start.atIndex(3)?.stringValue, !caption.isEmpty,
              let word = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else {
            throw AppFailure.wordResponse
        }
        try await WordWindowAccess.setFullScreen(enabled, windowCaption: caption, wordPID: word.processIdentifier)
    }

    func edit(_ document: WordDocument, tail: WordTail, replacing expected: String = "",
              at position: Int32? = nil, with text: String) throws -> WordTail {
        let args = identity(document) + [
            NSAppleEventDescriptor(int32: tail.position),
            NSAppleEventDescriptor(string: tail.text),
            NSAppleEventDescriptor(string: expected),
            NSAppleEventDescriptor(string: text.replacingOccurrences(of: "\n", with: "\r")),
            NSAppleEventDescriptor(int32: position ?? tail.position - 1)
        ]
        return try readTail(call("edit", arguments: args))
    }

    private func identity(_ document: WordDocument) -> [NSAppleEventDescriptor] {
        [NSAppleEventDescriptor(string: document.name), NSAppleEventDescriptor(string: document.path)]
    }

    private func readTail(_ descriptor: NSAppleEventDescriptor) throws -> WordTail {
        guard descriptor.numberOfItems >= 2,
              let position = descriptor.atIndex(1)?.int32Value,
              let text = descriptor.atIndex(2)?.stringValue else { throw AppFailure.wordResponse }
        return WordTail(position: position, text: text)
    }

    private func call(_ command: String, arguments: [NSAppleEventDescriptor] = []) throws -> NSAppleEventDescriptor {
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty else {
            throw AppFailure.setup("Open Microsoft Word and the document you want to write to.")
        }
        guard let script else { throw AppFailure.wordResponse }
        var details: NSDictionary?
        if !script.isCompiled, !script.compileAndReturnError(&details) {
            throw wordError(details)
        }
        let args = NSAppleEventDescriptor.list()
        for (offset, argument) in arguments.enumerated() {
            args.insert(argument, at: offset + 1)
        }
        let parameters = NSAppleEventDescriptor.list()
        parameters.insert(NSAppleEventDescriptor(string: command), at: 1)
        parameters.insert(args, at: 2)

        // AppleScript's ascr/psbr event calls a named handler with typed arguments.
        let event = NSAppleEventDescriptor(
            eventClass: 0x61736372, eventID: 0x70736272, targetDescriptor: nil,
            returnID: -1, transactionID: 0
        )
        event.setParam(NSAppleEventDescriptor(string: "dispatchCommand"), forKeyword: 0x736e616d)
        event.setParam(parameters, forKeyword: 0x2d2d2d2d)
        let result = script.executeAppleEvent(event, error: &details)
        if let details { throw wordError(details) }
        return result
    }

    private static let permissionInstructions = "Allow Word Cadence to control Microsoft Word in System Settings → Privacy & Security → Automation, then refresh."

    private func wordError(_ details: NSDictionary?) -> Error {
        let number = details?[NSAppleScript.errorNumber] as? Int
        if number == Int(errAEEventNotPermitted) || number == Int(errAEEventWouldRequireUserConsent) {
            return AppFailure.setup(Self.permissionInstructions)
        }
        if number == -1712 {
            return AppFailure.setup("Microsoft Word did not respond. Close any dialogs in Word and check the document before retrying.")
        }
        if number == 7002 { return AppFailure.wordMinimize }
        let message = details?[NSAppleScript.errorMessage] as? String
        return AppFailure.setup(message ?? "Microsoft Word did not return a usable response.")
    }
}
