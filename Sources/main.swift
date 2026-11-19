import AppKit
import Carbon.HIToolbox
import OSLog
import ScreenCaptureKit
import Vision

enum Config {
    static let regionKey = "captureRegion"
    static let launchBadgeSeconds = 3.0
    static let ollamaURL = URL(string: "http://127.0.0.1:11434")!
    static let requestTimeout: TimeInterval = 180
    static let ollamaBootSeconds = 15
    static let ollamaPaths = ["/opt/homebrew/bin/ollama", "/usr/local/bin/ollama",
                              "/Applications/Ollama.app/Contents/Resources/ollama"]
    static let thinking = "…"
    static let failed = "!"
    // Top-left screen corner: rest the mouse there this long to re-select the region.
    static let cornerDwellSeconds = 2.0
    static let cornerPollInterval: TimeInterval = 0.25
    static let cornerSize: CGFloat = 4
}

let log = Logger(subsystem: "local.onthi", category: "app")

struct OllamaError: Error { let detail: String }

// MARK: - Pipeline: screenshot → OCR → model

func recognizeText(_ image: CGImage) throws -> String {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    let supported = (try? request.supportedRecognitionLanguages()) ?? []
    request.recognitionLanguages = supported.filter { $0.hasPrefix("vi") } + ["en-US"]
    try VNImageRequestHandler(cgImage: image).perform([request])
    return (request.results ?? [])
        .compactMap { $0.topCandidates(1).first?.string }
        .joined(separator: "\n")
}

/// Keeps the last screenshot + OCR text in ~/Library/Caches/local.onthi/ for troubleshooting "?" answers.
func saveLastCapture(_ image: CGImage, text: String) {
    let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("local.onthi", isDirectory: true)
    do {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        try png?.write(to: dir.appendingPathComponent("last.png"))
        try text.write(to: dir.appendingPathComponent("last.txt"), atomically: true, encoding: .utf8)
    } catch {
        log.error("saving last capture failed: \(error)")
    }
}

func isOllamaUp() async -> Bool {
    var request = URLRequest(url: Config.ollamaURL.appendingPathComponent("api/version"))
    request.timeoutInterval = 1
    let response = try? await URLSession.shared.data(for: request).1
    return (response as? HTTPURLResponse)?.statusCode == 200
}

func waitForOllama() async throws {
    for _ in 0..<(Config.ollamaBootSeconds * 2) {
        if await isOllamaUp() { return }
        try await Task.sleep(for: .milliseconds(500))
    }
    throw OllamaError(detail: "Ollama not reachable at \(Config.ollamaURL)")
}

func askModel(_ question: String) async throws -> String {
    try await waitForOllama()
    var request = URLRequest(url: Config.ollamaURL.appendingPathComponent("api/chat"))
    request.httpMethod = "POST"
    request.timeoutInterval = Config.requestTimeout
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    let body: [String: Any] = [
        "model": Quiz.model, "stream": false, "think": true, "keep_alive": Quiz.keepAlive,
        "messages": [["role": "system", "content": Quiz.systemPrompt],
                     ["role": "user", "content": question]],
    ]
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    let (data, response) = try await URLSession.shared.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
        throw OllamaError(detail: String(decoding: data, as: UTF8.self))
    }
    struct Reply: Decodable { struct Message: Decodable { let content: String }; let message: Message }
    let content = try JSONDecoder().decode(Reply.self, from: data).message.content
    log.info("model reply: \(content, privacy: .public)")
    return Quiz.parseAnswer(content)
}

// MARK: - Region selection overlay

final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

/// Nothing visible by request: no dimming, no outlines — just the crosshair cursor while dragging.
final class SelectionView: NSView {
    // Near-zero alpha: fully transparent pixels would let clicks fall through to the app below.
    private static let catchAllFill = NSColor.black.withAlphaComponent(0.003)

    private var start: NSPoint?
    private var selection = NSRect.zero
    private let onDone: (NSRect?) -> Void

    init(frame: NSRect, onDone: @escaping (NSRect?) -> Void) {
        self.onDone = onDone
        super.init(frame: frame)
    }
    required init?(coder: NSCoder) { nil }

    override var acceptsFirstResponder: Bool { true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }

    override func mouseDown(with event: NSEvent) { start = convert(event.locationInWindow, from: nil) }
    override func mouseDragged(with event: NSEvent) {
        guard let start else { return }
        let point = convert(event.locationInWindow, from: nil)
        selection = NSRect(x: min(start.x, point.x), y: min(start.y, point.y),
                           width: abs(point.x - start.x), height: abs(point.y - start.y))
    }
    override func mouseUp(with event: NSEvent) {
        onDone(selection.width > 10 && selection.height > 10 ? selection : nil)
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) { onDone(nil) }
    }
    override func draw(_ dirtyRect: NSRect) {
        Self.catchAllFill.setFill() // invisible; only the crosshair cursor shows
        bounds.fill()
    }
}

// MARK: - App

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let menu = NSMenu()
    private lazy var label = AnswerLabel(menu: menu) { [weak self] in self?.ask() }
    private var job: Task<Void, Never>?
    private var clearWork: DispatchWorkItem?
    private var ollamaProcess: Process?
    private var overlay: NSWindow?
    private var cornerTimer: Timer?
    private var cornerEnteredAt: Date?
    private var cornerFired = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Opened by clicking the corner label (the menu bar item was hidden by the notch, so it is gone).
        let reselect = NSMenuItem(title: "Chọn lại vùng", action: #selector(selectRegion), keyEquivalent: "")
        reselect.target = self
        let quit = NSMenuItem(title: "Thoát", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        quit.target = NSApp
        menu.items = [reselect, quit]
        registerHotKey()
        startOllamaIfNeeded()
        // Without the grant captures come back as bare wallpaper, so say so up front.
        if CGPreflightScreenCaptureAccess() {
            show("✓", autoHide: true) // brief launch confirmation, then the idle dot
        } else {
            CGRequestScreenCaptureAccess()
            show(Config.failed)
        }
        if savedRegion() == nil { selectRegion() }
        startCornerWatch()
    }

    /// Double-clicking the app icon while it runs re-selects the region (no keyboard needed).
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        show("")
        selectRegion()
        return false
    }

    // Polling the mouse position needs no permission and no window that could block clicks.
    private func startCornerWatch() {
        cornerTimer = Timer.scheduledTimer(withTimeInterval: Config.cornerPollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkCorner() }
        }
    }

    /// Mouse resting in the top-left corner for 2s → re-select region, once per visit.
    private func checkCorner() {
        guard let screen = NSScreen.screens.first else { return }
        let mouse = NSEvent.mouseLocation
        let isInCorner = mouse.x <= screen.frame.minX + Config.cornerSize
            && mouse.y >= screen.frame.maxY - Config.cornerSize
        guard isInCorner else {
            cornerEnteredAt = nil
            cornerFired = false
            return
        }
        guard !cornerFired else { return }
        let enteredAt = cornerEnteredAt ?? Date()
        cornerEnteredAt = enteredAt
        guard Date().timeIntervalSince(enteredAt) >= Config.cornerDwellSeconds else { return }
        cornerFired = true
        show("")
        selectRegion()
    }

    func applicationWillTerminate(_ notification: Notification) {
        ollamaProcess?.terminate() // only the one we started; a pre-existing Ollama is left alone
    }

    // Carbon hotkeys work globally without Accessibility permission.
    // ⌃⌥A ask, ⌃⌥R re-select region, ⌃⌥Q quit (the menu itself may be hidden by the notch).
    private func registerHotKey() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            var key = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &key)
            let me = Unmanaged<AppDelegate>.fromOpaque(context!).takeUnretainedValue()
            Task { @MainActor in me.hotKeyPressed(key.id) }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), nil)
        for (id, keyCode) in [(UInt32(1), kVK_ANSI_A), (2, kVK_ANSI_R), (3, kVK_ANSI_Q)] {
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(UInt32(keyCode), UInt32(controlKey | optionKey),
                                             EventHotKeyID(signature: OSType(0x4F4E5448), id: id), // "ONTH"
                                             GetApplicationEventTarget(), 0, &ref)
            if status != noErr {
                log.error("RegisterEventHotKey \(id) failed: \(status)")
                show(Config.failed)
            }
        }
    }

    private func hotKeyPressed(_ id: UInt32) {
        switch id {
        case 1: ask()
        case 2:
            show("")
            selectRegion()
        case 3: NSApp.terminate(nil)
        default: break
        }
    }

    private func startOllamaIfNeeded() {
        Task {
            if await isOllamaUp() { return }
            guard let path = Config.ollamaPaths.first(where: FileManager.default.isExecutableFile) else {
                log.error("ollama binary not found in \(Config.ollamaPaths)")
                show(Config.failed)
                return
            }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = ["serve"]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                ollamaProcess = process
            } catch {
                log.error("starting ollama failed: \(error)")
                show(Config.failed)
            }
        }
    }

    /// Triggered by resting the mouse on the corner dot, or ⌃⌥A. One capture per ask.
    private func ask() {
        guard overlay == nil else { return }
        guard let region = savedRegion() else { selectRegion(); return }
        job?.cancel() // newest ask wins over an answer still being computed
        clearWork?.cancel()
        setTitle(Config.thinking)
        job = Task {
            var answer: String
            do {
                let image = try await SCScreenshotManager.captureImage(in: region)
                let text = try recognizeText(image)
                saveLastCapture(image, text: text)
                // Not a quiz on screen: say "?" now instead of spending model time on it.
                answer = Quiz.looksLikeQuestion(text) ? try await askModel(text) : Quiz.unsure
            } catch {
                log.error("answer failed: \(error)")
                answer = Config.failed
            }
            if Task.isCancelled { return }
            show(answer)
        }
    }

    /// Answers stay until the next ask; only the launch ✓ hides itself.
    private func show(_ text: String, autoHide: Bool = false) {
        clearWork?.cancel()
        setTitle(text)
        guard autoHide else { return }
        let work = DispatchWorkItem { [weak self] in self?.setTitle("") }
        clearWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Config.launchBadgeSeconds, execute: work)
    }

    private func setTitle(_ text: String) {
        label.show(text)
    }

    // Stored in CoreGraphics global coordinates (top-left origin of the main display).
    private func savedRegion() -> CGRect? {
        guard let values = UserDefaults.standard.array(forKey: Config.regionKey) as? [Double],
              values.count == 4 else { return nil }
        return CGRect(x: values[0], y: values[1], width: values[2], height: values[3])
    }

    @objc private func selectRegion() {
        guard overlay == nil, let screen = NSScreen.screens.first else { return }
        let window = OverlayWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        // The overlay needs key focus for the drag; hand it back to whatever was in front afterwards.
        let previousApp = NSWorkspace.shared.frontmostApplication
            .flatMap { $0 == NSRunningApplication.current ? nil : $0 }
        let size = screen.frame.size
        window.contentView = SelectionView(frame: NSRect(origin: .zero, size: size)) { [weak self] rect in
            if let rect {
                let cg = [rect.minX, size.height - rect.maxY, rect.width, rect.height].map(Double.init)
                UserDefaults.standard.set(cg, forKey: Config.regionKey)
            }
            self?.overlay?.orderOut(nil)
            self?.overlay = nil
            previousApp?.activate()
        }
        overlay = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(window.contentView)
    }
}

let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() } // top-level code runs on the main thread
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
