import AppKit
import ApplicationServices

@MainActor
enum WordWindowAccess {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func requireAccessibility() throws {
        guard !isTrusted else { return }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
        throw AppFailure.setup("Allow Word Cadence in System Settings → Privacy & Security → Accessibility, then click Write to Word again.")
    }

    static func setFullScreen(_ enabled: Bool, windowCaption: String, wordPID: pid_t) async throws {
        let application = AXUIElementCreateApplication(wordPID)
        let attribute = "AXFullScreen"
        let window = try await selectedWindow(in: application, caption: windowCaption)
        if value(attribute, of: window) as? Bool == enabled { return }

        let desiredValue: CFBoolean = enabled ? kCFBooleanTrue : kCFBooleanFalse
        let status = AXUIElementSetAttributeValue(window, attribute as CFString, desiredValue)
        guard status == .success || status == .cannotComplete else {
            throw AppFailure.setup("Word could not change Full Screen for the selected window.")
        }

        // macOS changes Spaces asynchronously. Verify the new window state before writing.
        for _ in 0..<25 {
            try await Task.sleep(for: .milliseconds(100))
            if value(attribute, of: window) as? Bool == enabled { return }
        }
        throw AppFailure.setup("Word did not finish changing Full Screen. Check the selected window and try again.")
    }

    private static func selectedWindow(in application: AXUIElement, caption: String) async throws -> AXUIElement {
        for _ in 0..<15 {
            try Task.checkCancellation()
            for attribute in [kAXMainWindowAttribute, kAXFocusedWindowAttribute] {
                guard let object = value(attribute, of: application),
                      CFGetTypeID(object) == AXUIElementGetTypeID() else { continue }
                let window = object as! AXUIElement
                if (value(kAXTitleAttribute, of: window) as? String) == caption { return window }
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw AppFailure.setup("Word did not report the selected window. Close any Word dialogs and try again.")
    }

    private static func value(_ attribute: String, of element: AXUIElement) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &result) == .success else { return nil }
        return result
    }
}
