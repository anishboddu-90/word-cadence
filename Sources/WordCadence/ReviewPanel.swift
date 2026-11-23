import AppKit
import SwiftUI

@MainActor
final class ReviewPanel: NSPanel {
    private static let initialSize = NSSize(width: 960, height: 650)

    init<Content: View>(@ViewBuilder content: () -> Content) {
        super.init(contentRect: NSRect(origin: .zero, size: Self.initialSize),
                   styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        title = "Review Photo Transcript"
        minSize = NSSize(width: 730, height: 540)
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentViewController = NSHostingController(rootView: content())
    }

    override var canBecomeKey: Bool { true }

    func present() {
        if !isVisible {
            let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
            if let area = screen?.visibleFrame {
                let size = NSSize(width: min(area.width, Self.initialSize.width),
                                  height: min(area.height, Self.initialSize.height))
                let centered = NSRect(x: area.midX - size.width / 2, y: area.midY - size.height / 2,
                                      width: size.width, height: size.height)
                setFrame(centered, display: true)
            }
        }
        orderFrontRegardless()
    }
}
