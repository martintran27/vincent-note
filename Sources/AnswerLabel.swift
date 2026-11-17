import AppKit

/// Bare light-gray character at the top-right of the main screen, just under the menu bar.
/// Used instead of the status item because a crowded notched menu bar can hide it.
/// When idle it shows a faint dot. Resting the mouse on it asks; clicking opens the app menu,
/// so nothing needs the keyboard.
@MainActor
final class AnswerLabel {
    private static let size = NSSize(width: 34, height: 30)
    private static let margin: CGFloat = 8
    private static let idleDot = "·"
    private static let textColor = NSColor(white: 0.62, alpha: 0.85)
    private static let idleColor = NSColor(white: 0.62, alpha: 0.4)

    private let panel: NSPanel
    private let field = NSTextField(labelWithString: "")

    init(menu: NSMenu, onDwell: @escaping () -> Void) {
        panel = NSPanel(contentRect: NSRect(origin: .zero, size: Self.size),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let box = LabelView(frame: NSRect(origin: .zero, size: Self.size), menu: menu, onDwell: onDwell)
        field.font = .monospacedSystemFont(ofSize: 16, weight: .regular)
        field.alignment = .center
        box.addSubview(field)
        panel.contentView = box
    }

    /// Empty text shows the idle dot.
    func show(_ text: String) {
        guard let screen = NSScreen.screens.first else { return }
        field.stringValue = text.isEmpty ? Self.idleDot : text
        field.textColor = text.isEmpty ? Self.idleColor : Self.textColor
        field.sizeToFit()
        field.frame = NSRect(x: 0, y: (Self.size.height - field.frame.height) / 2,
                             width: Self.size.width, height: field.frame.height)
        let visible = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(x: visible.maxX - Self.size.width - Self.margin,
                                     y: visible.maxY - Self.size.height - Self.margin))
        panel.orderFrontRegardless()
    }
}

/// Whole label area is the target: rest the mouse 0.5s to ask, click for the menu.
/// The text field on top must not swallow the mouse.
private final class LabelView: NSView {
    private static let dwellSeconds = 0.5

    private let clickMenu: NSMenu
    private let onDwell: () -> Void
    private var dwellWork: DispatchWorkItem?

    init(frame: NSRect, menu: NSMenu, onDwell: @escaping () -> Void) {
        self.clickMenu = menu
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

    override func hitTest(_ point: NSPoint) -> NSView? { frame.contains(point) ? self : nil }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {
        clickMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: bounds.minY), in: self)
    }
}
