import AppKit
import Foundation

@main
struct AppIconRenderer {
    @MainActor
    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            throw NSError(
                domain: "LidGuardIconRenderer",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Usage: render-app-icon <output.png>"]
            )
        }

        let outputPath = CommandLine.arguments[1]
        let size = NSSize(width: 1024, height: 1024)
        let image = NSImage(size: size, flipped: false) { bounds in
            drawIcon(in: bounds)
            return true
        }

        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try png.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
    }

    @MainActor
    private static func drawIcon(in bounds: NSRect) {
        NSGraphicsContext.current?.imageInterpolation = .high

        let tile = NSBezierPath(roundedRect: bounds.insetBy(dx: 64, dy: 64), xRadius: 216, yRadius: 216)
        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.055, green: 0.12, blue: 0.22, alpha: 1),
            NSColor(calibratedRed: 0.025, green: 0.29, blue: 0.32, alpha: 1),
        ])!
        gradient.draw(in: tile, angle: -55)

        NSColor.white.withAlphaComponent(0.12).setStroke()
        tile.lineWidth = 10
        tile.stroke()

        let screen = NSBezierPath(roundedRect: NSRect(x: 250, y: 300, width: 524, height: 332), xRadius: 44, yRadius: 44)
        NSColor.white.setStroke()
        screen.lineWidth = 42
        screen.stroke()

        let base = NSBezierPath()
        base.move(to: NSPoint(x: 190, y: 248))
        base.line(to: NSPoint(x: 834, y: 248))
        base.lineCapStyle = .round
        base.lineWidth = 46
        base.stroke()

        NSColor(calibratedRed: 0.14, green: 0.9, blue: 0.48, alpha: 1).setStroke()
        let arrow = NSBezierPath()
        arrow.move(to: NSPoint(x: 512, y: 748))
        arrow.line(to: NSPoint(x: 512, y: 438))
        arrow.move(to: NSPoint(x: 398, y: 536))
        arrow.line(to: NSPoint(x: 512, y: 422))
        arrow.line(to: NSPoint(x: 626, y: 536))
        arrow.lineCapStyle = .round
        arrow.lineJoinStyle = .round
        arrow.lineWidth = 58
        arrow.stroke()
    }
}
