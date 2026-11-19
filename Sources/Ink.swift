import AppKit
import ScreenCaptureKit

/// Faint gray that does not vanish into the page: dark gray on light backgrounds, light gray on dark ones.
struct Ink {
    private static let grayOnLight: CGFloat = 0.3
    private static let grayOnDark: CGFloat = 0.85
    private static let alpha: CGFloat = 0.2 // as faint as the user asked; no setting by request
    private static let idleShare: CGFloat = 0.6 // the idle dot is fainter still

    let text: NSColor
    let idle: NSColor

    init(isBackgroundDark: Bool) {
        let gray = isBackgroundDark ? Self.grayOnDark : Self.grayOnLight
        text = NSColor(white: gray, alpha: Self.alpha)
        idle = NSColor(white: gray, alpha: Self.alpha * Self.idleShare)
    }
}

/// Average brightness (0 = black … 1 = white) of the screen inside `frame`, in AppKit screen
/// coordinates. One tiny screenshot, so macOS's recording indicator blinks briefly.
func backgroundBrightness(under frame: NSRect) async -> CGFloat? {
    guard let primary = NSScreen.screens.first else { return nil }
    let rect = CGRect(x: frame.minX, y: primary.frame.height - frame.maxY, width: frame.width, height: frame.height)
    guard let image = try? await SCScreenshotManager.captureImage(in: rect) else { return nil }
    var pixel: UInt8 = 0
    guard let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 1,
                                  space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
    context.interpolationQuality = .medium
    context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1)) // averages the whole area
    return CGFloat(pixel) / 255
}
