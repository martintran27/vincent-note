import AppKit

/// The answer itself, separate from the trigger dot: a letter, a status ("…", "?", "!") or one line
/// of a free-form solution, in small faint text with no background. Drag it anywhere (the spot is
/// remembered); scroll over it to step through a solution. Never takes focus.
/// Its right edge is the anchor, so longer lines grow to the left; near the left screen edge they
/// are pushed right instead of running off-screen.
@MainActor
final class AnswerLine {
    private static let height: CGFloat = 30
    private static let padding: CGFloat = 6
    private static let minWidth: CGFloat = 30
    private static let maxWidth: CGFloat = 620
    private static let anchorKey = "answerAnchor"
    private static let font = NSFont.systemFont(ofSize: 13)

    private let panel: NSPanel
    private let field = NSTextField(labelWithString: "")
    private var anchor: NSPoint // right edge x, vertical middle y, in screen coordinates

    /// `defaultAnchor` is used until the user drags the line somewhere.
    init(defaultAnchor: NSPoint, onScroll: @escaping (Int) -> Void, onMoved: @escaping () -> Void) {
        anchor = Self.savedAnchor() ?? defaultAnchor
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: Self.minWidth, height: Self.height),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let view = AnswerLineView(onScroll: onScroll) { [weak self] in
            guard let self else { return }
            anchor = NSPoint(x: panel.frame.maxX, y: panel.frame.midY)
            UserDefaults.standard.set([Double(anchor.x), Double(anchor.y)], forKey: Self.anchorKey)
            onMoved()
        }
        field.font = Self.font
        field.lineBreakMode = .byTruncatingMiddle
        view.addSubview(field)
        panel.contentView = view
    }

    /// Where the line sits now (or would sit), for sampling the background behind it.
    var area: NSRect {
        NSRect(x: anchor.x - Self.maxWidth / 2, y: anchor.y - Self.height / 2, width: Self.maxWidth / 2, height: Self.height)
    }

    func show(_ text: String, color: NSColor) {
        field.stringValue = text
        field.textColor = color
        field.sizeToFit()
        let width = min(max(field.frame.width + Self.padding * 2, Self.minWidth), Self.maxWidth)
        let screenMinX = NSScreen.screens.first?.frame.minX ?? 0
        let x = max(anchor.x - width, screenMinX)
        panel.setFrame(NSRect(x: x, y: anchor.y - Self.height / 2, width: width, height: Self.height), display: true)
        field.frame = NSRect(x: Self.padding, y: (Self.height - field.frame.height) / 2,
                             width: width - Self.padding * 2, height: field.frame.height)
        panel.orderFrontRegardless()
    }

    func hide() { panel.orderOut(nil) }

    /// Saved spot, ignored when it no longer lies on any screen (e.g. an external display was unplugged).
    private static func savedAnchor() -> NSPoint? {
        guard let values = UserDefaults.standard.array(forKey: anchorKey) as? [Double], values.count == 2 else {
            return nil
        }
        let point = NSPoint(x: values[0], y: values[1])
        return NSScreen.screens.contains { $0.frame.insetBy(dx: -1, dy: -1).contains(point) } ? point : nil
    }
}

/// Drag to move; scroll to step: +1 = next line, -1 = previous. One swipe = one line
/// (trackpad inertia is ignored, so a flick no longer jumps several lines).
private final class AnswerLineView: NSView {
    private static let trackpadPointsPerStep: CGFloat = 12
    private static let dragThreshold: CGFloat = 3

    private let onScroll: (Int) -> Void
    private let onMoved: () -> Void
    private var pending: CGFloat = 0
    private var hasSteppedThisSwipe = false
    private var dragStart: NSPoint?
    private var originAtDragStart = NSPoint.zero
    private var isDragging = false

    init(onScroll: @escaping (Int) -> Void, onMoved: @escaping () -> Void) {
        self.onScroll = onScroll
        self.onMoved = onMoved
        super.init(frame: .zero)
        autoresizingMask = [.width, .height]
    }
    required init?(coder: NSCoder) { nil }

    override func hitTest(_ point: NSPoint) -> NSView? { frame.contains(point) ? self : nil }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // The window server lets clicks and scrolls fall through fully transparent pixels,
    // so paint an invisible, near-zero alpha fill over the whole line.
    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.003).setFill()
        bounds.fill()
    }

    override func mouseDown(with event: NSEvent) {
        dragStart = NSEvent.mouseLocation
        originAtDragStart = window?.frame.origin ?? .zero
        isDragging = false
    }
    override func mouseDragged(with event: NSEvent) {
        guard let dragStart, let window else { return }
        let now = NSEvent.mouseLocation
        let dx = now.x - dragStart.x
        let dy = now.y - dragStart.y
        if !isDragging && hypot(dx, dy) < Self.dragThreshold { return }
        isDragging = true
        window.setFrameOrigin(NSPoint(x: originAtDragStart.x + dx, y: originAtDragStart.y + dy))
    }
    override func mouseUp(with event: NSEvent) {
        dragStart = nil
        guard isDragging else { return }
        isDragging = false
        onMoved()
    }

    override func scrollWheel(with event: NSEvent) {
        // Content-style direction: scrolling "down" through the solution (negative delta) = next step.
        guard event.hasPreciseScrollingDeltas else { // mouse wheel: one notch, one step
            if event.scrollingDeltaY != 0 { onScroll(event.scrollingDeltaY < 0 ? 1 : -1) }
            return
        }
        guard event.momentumPhase.isEmpty else { return }
        if event.phase.contains(.began) {
            pending = 0
            hasSteppedThisSwipe = false
        }
        guard !hasSteppedThisSwipe else { return }
        pending += event.scrollingDeltaY
        if abs(pending) >= Self.trackpadPointsPerStep {
            onScroll(pending < 0 ? 1 : -1)
            hasSteppedThisSwipe = true
        }
    }
}
