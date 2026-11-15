import AppKit

/// Small floating pill under the menu bar, top-right of the main screen.
/// Used instead of the status item because a crowded notched menu bar can hide it.
@MainActor
final class AnswerLabel {
    private static let size = NSSize(width: 34, height: 30)
    private static let margin: CGFloat = 8

    private let panel: NSPanel
    private let field = NSTextField(labelWithString: "")

    init() {
        panel = NSPanel(contentRect: NSRect(origin: .zero, size: Self.size),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        // Minimal by request: bare light-gray character, no box, no background.
        let box = NSView(frame: NSRect(origin: .zero, size: Self.size))

        field.font = .monospacedSystemFont(ofSize: 16, weight: .regular)
        field.textColor = NSColor(white: 0.62, alpha: 0.85)
        field.alignment = .center
        box.addSubview(field)
        panel.contentView = box
    }

    /// Empty text hides the label.
    func show(_ text: String) {
        guard !text.isEmpty, let screen = NSScreen.screens.first else {
            panel.orderOut(nil)
            return
        }
        field.stringValue = text
        field.sizeToFit()
        field.frame = NSRect(x: 0, y: (Self.size.height - field.frame.height) / 2,
                             width: Self.size.width, height: field.frame.height)
        let visible = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(x: visible.maxX - Self.size.width - Self.margin,
                                     y: visible.maxY - Self.size.height - Self.margin))
        panel.orderFrontRegardless()
    }
}
