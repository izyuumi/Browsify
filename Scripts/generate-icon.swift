import AppKit
import CoreGraphics
import Foundation

/// Regenerates Browsify's macOS app-icon raster set from a single vector drawing.
/// Run from the repository root with: swift Scripts/generate-icon.swift

let iconSizes = [16, 32, 32, 64, 128, 256, 256, 512, 512, 1024]
let iconDirectory = URL(
    fileURLWithPath: FileManager.default.currentDirectoryPath,
    isDirectory: true
).appendingPathComponent("Browsify/Assets.xcassets/AppIcon.appiconset", isDirectory: true)

func drawIcon(in context: CGContext, size: Int) {
    let scale = CGFloat(size) / 1024
    context.scaleBy(x: scale, y: scale)
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.interpolationQuality = .high

    let canvas = CGRect(x: 0, y: 0, width: 1024, height: 1024)
    context.clear(canvas)

    let content = CGRect(x: 64, y: 64, width: 896, height: 896)
    let iconPath = CGPath(
        roundedRect: content,
        cornerWidth: 202,
        cornerHeight: 202,
        transform: nil
    )

    context.saveGState()
    context.addPath(iconPath)
    context.clip()
    let background = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor(calibratedRed: 0.12, green: 0.50, blue: 0.98, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.40, green: 0.19, blue: 0.87, alpha: 1).cgColor
        ] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        background,
        start: CGPoint(x: 512, y: 960),
        end: CGPoint(x: 512, y: 64),
        options: []
    )

    let highlight = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor.white.withAlphaComponent(0.30).cgColor,
            NSColor.white.withAlphaComponent(0).cgColor
        ] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        highlight,
        start: CGPoint(x: 512, y: 962),
        end: CGPoint(x: 512, y: 690),
        options: []
    )
    context.restoreGState()

    // A compact globe is the routing hub; three arrow paths make the outgoing choices explicit.
    context.setStrokeColor(NSColor.white.withAlphaComponent(0.96).cgColor)
    context.setLineWidth(46)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.strokeEllipse(in: CGRect(x: 304, y: 304, width: 416, height: 416))

    context.setLineWidth(25)
    context.strokeEllipse(in: CGRect(x: 410, y: 304, width: 204, height: 416))
    context.move(to: CGPoint(x: 306, y: 512))
    context.addLine(to: CGPoint(x: 718, y: 512))
    context.strokePath()

    func arrow(from: CGPoint, to: CGPoint) {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let length = max(hypot(dx, dy), 1)
        let unitX = dx / length
        let unitY = dy / length
        let perpendicular = CGPoint(x: -unitY, y: unitX)
        let headLength: CGFloat = 61
        let headWidth: CGFloat = 35
        let base = CGPoint(x: to.x - unitX * headLength, y: to.y - unitY * headLength)

        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(35)
        context.setLineCap(.round)
        context.move(to: from)
        context.addLine(to: base)
        context.strokePath()

        context.setFillColor(NSColor.white.cgColor)
        context.move(to: to)
        context.addLine(to: CGPoint(x: base.x + perpendicular.x * headWidth, y: base.y + perpendicular.y * headWidth))
        context.addLine(to: CGPoint(x: base.x - perpendicular.x * headWidth, y: base.y - perpendicular.y * headWidth))
        context.closePath()
        context.fillPath()
    }

    arrow(from: CGPoint(x: 520, y: 514), to: CGPoint(x: 796, y: 774))
    arrow(from: CGPoint(x: 520, y: 514), to: CGPoint(x: 838, y: 510))
    arrow(from: CGPoint(x: 520, y: 514), to: CGPoint(x: 770, y: 254))
}

func writePNG(size: Int, to url: URL) throws {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap)?.cgContext else {
        throw NSError(domain: "BrowsifyIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create bitmap context"])
    }

    drawIcon(in: context, size: size)
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "BrowsifyIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not encode PNG"])
    }
    try png.write(to: url, options: .atomic)
}

try FileManager.default.createDirectory(at: iconDirectory, withIntermediateDirectories: true)
for (index, size) in iconSizes.enumerated() {
    let filename = "BrowsifyIcon_\(index + 1)_\(size).png"
    try writePNG(size: size, to: iconDirectory.appendingPathComponent(filename))
    print("Wrote \(filename)")
}
