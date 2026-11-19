import AppKit

/// The fixed trigger: a faint dot at the top-right of the main screen, just under the menu bar
/// (used instead of a status item because a crowded notched menu bar can hide it).
/// Resting the mouse on it asks; clicks do nothing (no menu, so nothing can take focus).
/// It shows "+" while the region picker is open. Answers are shown elsewhere, by AnswerLine, which the user can drag around.
@MainActor
final class AnswerLabel {
    private static let size = NSSize(width: 34, height: 30)
    private static let margin: CGFloat = 8
    private static let idleDot = "·"

    private let panel: NSPanel
    private let field = NSTextField(labelWithString: "")
    private var text = ""
    private var textColor = NSColor(white: 0.6, alpha: 0.4)
    private var idleColor = NSColor(white: 0.6, alpha: 0.25)

    var frame: NSRect { panel.frame }

    init(onDwell: @escaping () -> Void) {
        panel = NSPanel(contentRect: NSRect(origin: .zero, size: Self.size),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let box = LabelView(frame: NSRect(origin: .zero, size: Self.size), onDwell: onDwell)
        field.font = .monospacedSystemFont(ofSize: 16, weight: .regular)
        field.alignment = .center
        box.addSubview(field)
        panel.contentView = box
        let visible = NSScreen.screens.first?.visibleFrame ?? .zero
        panel.setFrameOrigin(NSPoint(x: visible.maxX - Self.size.width - Self.margin,
                                     y: visible.maxY - Self.size.height - Self.margin))
    }

    /// Empty text shows the idle dot.
    func show(_ text: String) {
        self.text = text
        field.stringValue = text.isEmpty ? Self.idleDot : text
        field.textColor = text.isEmpty ? idleColor : textColor
        field.sizeToFit()
        field.frame = NSRect(x: 0, y: (Self.size.height - field.frame.height) / 2,
                             width: Self.size.width, height: field.frame.height)
        panel.orderFrontRegardless()
    }

    func setColors(text textColor: NSColor, idle idleColor: NSColor) {
        self.textColor = textColor
        self.idleColor = idleColor
        show(text)
    }
}

/// Whole label area is the target: rest the mouse 0.5s to ask.
/// The text field on top must not swallow the mouse.
private final class LabelView: NSView {
    private static let dwellSeconds = 0.5

    private let onDwell: () -> Void
    private var dwellWork: DispatchWorkItem?

    init(frame: NSRect, onDwell: @escaping () -> Void) {
        self.onDwell = onDwell
        super.init(frame: frame)
        // .activeAlways: the panel never becomes key, yet hover must still register.
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways],
                                       owner: self, userInfo: nil))
    }
    required init?(coder: NSCoder) { nil }

    override func mouseEntered(with event: NSEvent) {
        let work = DispatchWorkItem { [weak self] in self?.onDwell() } // once per visit
        dwellWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.dwellSeconds, execute: work)
    }
    override func mouseExited(with event: NSEvent) {
        dwellWork?.cancel()
        dwellWork = nil
    }

}
