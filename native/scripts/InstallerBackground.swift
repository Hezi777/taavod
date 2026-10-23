import AppKit
import Foundation

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let width = 1520
let height = 1040
let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: width,
    pixelsHigh: height,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
bitmap.size = NSSize(width: 760, height: 520)
let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphics
graphics.imageInterpolation = .high
let context = graphics.cgContext
context.scaleBy(x: 0.5, y: 0.5)
let bounds = CGRect(x: 0, y: 0, width: width, height: height)

NSColor(calibratedRed: 0.027, green: 0.031, blue: 0.043, alpha: 1).setFill()
bounds.fill()

let glowColors = [
    NSColor(calibratedRed: 0.36, green: 0.22, blue: 0.72, alpha: 0.24).cgColor,
    NSColor(calibratedRed: 0.15, green: 0.11, blue: 0.30, alpha: 0.08).cgColor,
    NSColor(calibratedRed: 0.027, green: 0.031, blue: 0.043, alpha: 0).cgColor
] as CFArray
let locations: [CGFloat] = [0, 0.42, 1]
if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glowColors, locations: locations) {
    context.drawRadialGradient(
        gradient,
        startCenter: CGPoint(x: 1110, y: 520),
        startRadius: 0,
        endCenter: CGPoint(x: 1110, y: 520),
        endRadius: 750,
        options: [.drawsAfterEndLocation]
    )
}

func drawText(_ value: String, at point: CGPoint, font: NSFont, color: NSColor, kern: CGFloat = 0) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .kern: kern,
        .paragraphStyle: paragraph
    ]
    let size = value.size(withAttributes: attributes)
    value.draw(at: CGPoint(x: point.x - size.width / 2, y: point.y), withAttributes: attributes)
}

let white = NSColor(calibratedWhite: 0.96, alpha: 1)
let secondary = NSColor(calibratedWhite: 0.68, alpha: 1)
let faint = NSColor(calibratedWhite: 1, alpha: 0.10)
let purple = NSColor(calibratedRed: 0.58, green: 0.39, blue: 1, alpha: 1)

drawText("TAAVOD", at: CGPoint(x: 760, y: 850), font: .systemFont(ofSize: 46, weight: .semibold), color: white, kern: 5)
drawText("Career practice, made personal.", at: CGPoint(x: 760, y: 800), font: .systemFont(ofSize: 20, weight: .regular), color: secondary)

context.setStrokeColor(faint.cgColor)
context.setLineWidth(1)
context.move(to: CGPoint(x: 250, y: 680))
context.addLine(to: CGPoint(x: 1270, y: 680))
context.strokePath()

// The app and Applications icons sit at x=200 and x=560 in Finder's 760pt window.
// This quiet directional mark connects them without competing with the icons.
let arrow = NSBezierPath()
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
arrow.lineWidth = 3
arrow.move(to: CGPoint(x: 620, y: 476))
arrow.line(to: CGPoint(x: 810, y: 476))
arrow.move(to: CGPoint(x: 792, y: 493))
arrow.line(to: CGPoint(x: 810, y: 476))
arrow.line(to: CGPoint(x: 792, y: 459))
purple.withAlphaComponent(0.82).setStroke()
arrow.stroke()

// Finder uses dark file labels over picture backgrounds.
NSColor(calibratedWhite: 0.92, alpha: 1).setFill()
for labelRect in [CGRect(x: 310, y: 307, width: 180, height: 52), CGRect(x: 1000, y: 307, width: 240, height: 52)] {
    NSBezierPath(roundedRect: labelRect, xRadius: 26, yRadius: 26).fill()
}

context.setStrokeColor(faint.cgColor)
context.setLineWidth(1)
context.move(to: CGPoint(x: 250, y: 180))
context.addLine(to: CGPoint(x: 1270, y: 180))
context.strokePath()

drawText("DRAG TAAVOD TO APPLICATIONS", at: CGPoint(x: 760, y: 100), font: .systemFont(ofSize: 15, weight: .medium), color: secondary, kern: 2.2)
drawText("Your local workspace is ready when you are.", at: CGPoint(x: 760, y: 64), font: .systemFont(ofSize: 13), color: NSColor(calibratedWhite: 0.48, alpha: 1))

NSGraphicsContext.restoreGraphicsState()
let png = bitmap.representation(using: .png, properties: [:])!
try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try png.write(to: outputURL, options: .atomic)
