#!/usr/bin/env swift
import AppKit

let outputDir = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "ZApiInfo/Assets.xcassets/AppIcon.appiconset")

try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

func drawIcon() -> NSImage {
    NSImage(size: NSSize(width: 1024, height: 1024), flipped: false) { rect in
        guard let context = NSGraphicsContext.current?.cgContext else { return false }
        let size = min(rect.width, rect.height)
        let inset = size * 0.08
        let box = rect.insetBy(dx: inset, dy: inset)
        let radius = box.width * 0.22

        let path = NSBezierPath(roundedRect: box, xRadius: radius, yRadius: radius)
        context.saveGState()
        path.addClip()

        let colors = [
            NSColor(calibratedRed: 0.06, green: 0.28, blue: 0.42, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.10, green: 0.55, blue: 0.62, alpha: 1).cgColor
        ]
        if let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors as CFArray,
            locations: [0, 1]
        ) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: box.minX, y: box.maxY),
                end: CGPoint(x: box.maxX, y: box.minY),
                options: []
            )
        }

        let pad = box.width * 0.22
        let chart = box.insetBy(dx: pad, dy: pad)
        let barWidth = chart.width * 0.18
        let gap = (chart.width - barWidth * 3) / 2
        let heights: [CGFloat] = [0.42, 0.68, 1.0]
        let barColor = NSColor.white.withAlphaComponent(0.92)
        barColor.setFill()
        for (index, ratio) in heights.enumerated() {
            let height = chart.height * ratio
            let x = chart.minX + CGFloat(index) * (barWidth + gap)
            let bar = NSRect(x: x, y: chart.minY, width: barWidth, height: height)
            let barRadius = min(barWidth, height) * 0.28
            NSBezierPath(roundedRect: bar, xRadius: barRadius, yRadius: barRadius).fill()
        }

        context.restoreGState()
        return true
    }
}

let master = drawIcon()
let sizes: [(name: String, px: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for item in sizes {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: item.px,
        pixelsHigh: item.px,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    bitmap.size = NSSize(width: item.px, height: item.px)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current?.imageInterpolation = .high
    master.draw(
        in: NSRect(x: 0, y: 0, width: item.px, height: item.px),
        from: .zero,
        operation: .copy,
        fraction: 1
    )
    NSGraphicsContext.restoreGraphicsState()
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        fputs("Failed to write \(item.name)\n", stderr)
        exit(1)
    }
    try data.write(to: outputDir.appendingPathComponent(item.name))
}

print("Wrote icons to \(outputDir.path)")
