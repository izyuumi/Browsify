import AppKit
import CoreGraphics
import Foundation
import ImageIO

let canvasSize = CGSize(width: 2880, height: 1800)
let maximumContentSize = CGSize(width: canvasSize.width * 0.8, height: canvasSize.height * 0.8)

func usage() -> Never {
    fputs("Usage: swift Scripts/composite-screenshot.swift <input.png> <output.png>\n", stderr)
    exit(64)
}

func image(at url: URL) throws -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw NSError(
            domain: "BrowsifyScreenshotComposite",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Could not read image at \(url.path)"]
        )
    }
    return image
}

func drawBackground(in context: CGContext) {
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor(calibratedRed: 0.12, green: 0.50, blue: 0.98, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.40, green: 0.19, blue: 0.87, alpha: 1).cgColor
        ] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: canvasSize.width * 0.22, y: canvasSize.height),
        end: CGPoint(x: canvasSize.width * 0.78, y: 0),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )
}

func scaledRect(for image: CGImage) -> CGRect {
    let scale = min(
        maximumContentSize.width / CGFloat(image.width),
        maximumContentSize.height / CGFloat(image.height)
    )
    let size = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
    return CGRect(
        x: (canvasSize.width - size.width) / 2,
        y: (canvasSize.height - size.height) / 2,
        width: size.width,
        height: size.height
    )
}

func composite(input: URL, output: URL) throws {
    let sourceImage = try image(at: input)
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(canvasSize.width),
        pixelsHigh: Int(canvasSize.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap)?.cgContext else {
        throw NSError(domain: "BrowsifyScreenshotComposite", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not create output context"])
    }

    drawBackground(in: context)
    let contentRect = scaledRect(for: sourceImage)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -18), blur: 36, color: NSColor.black.withAlphaComponent(0.28).cgColor)
    context.draw(sourceImage, in: contentRect)
    context.restoreGState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "BrowsifyScreenshotComposite", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not encode PNG"])
    }
    try png.write(to: output, options: .atomic)
}

guard CommandLine.arguments.count == 3 else {
    usage()
}

let input = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
try composite(input: input, output: output)
