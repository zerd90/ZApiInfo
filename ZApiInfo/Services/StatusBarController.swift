import AppKit
import CoreText
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    static private(set) weak var shared: StatusBarController?

    private let store: UsageStore
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var eventMonitor: Any?

    init(store: UsageStore) {
        self.store = store
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        Self.shared = self
        popover.behavior = .transient
        popover.animates = false
        if let button = statusItem.button {
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleNone
            button.action = #selector(togglePopover)
            button.target = self
            button.sendAction(on: [.leftMouseUp])
        }
        render()
        observe()
    }

    private func observe() {
        withObservationTracking {
            _ = store.statusBarText
            _ = store.status
            _ = store.language
            _ = store.statusBarFields().map(\.path)
            _ = store.values
            render()
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                self?.observe()
            }
        }
    }

    private func render() {
        let image = StatusBarRenderer.image(store: store)
        statusItem.button?.image = image
        statusItem.length = image.size.width + 2
        statusItem.button?.toolTip = store.statusBarAccessibilityLabel
    }

    func dismissPopover() {
        popover.performClose(nil)
        stopEventMonitor()
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            dismissPopover()
            return
        }
        let root = MenuPopoverView()
            .environment(store)
        let hosting = NSHostingController(rootView: root)
        hosting.sizingOptions = [.preferredContentSize, .intrinsicContentSize]
        popover.contentViewController = hosting
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        button.window?.makeKey()
        startEventMonitor()
    }

    private func startEventMonitor() {
        stopEventMonitor()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.popover.performClose(nil)
            self?.stopEventMonitor()
        }
    }

    private func stopEventMonitor() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }
}

enum StatusBarRenderer {
    @MainActor
    static func image(store: UsageStore) -> NSImage {
        let height = NSStatusBar.system.thickness
        let scale = NSScreen.main?.backingScaleFactor ?? 2

        let showMetrics: Bool = {
            if store.status == .unconfigured { return false }
            if store.status == .error, store.values.isEmpty { return false }
            return !store.statusBarFields().isEmpty
        }()

        if !showMetrics {
            return makeImage(size: measureSingleLine(store.statusBarText, height: height), scale: scale) { size in
                drawSingleLine(store.statusBarText, in: size)
            }
        }

        let fields = store.statusBarFields()
        let labels = fields.map(\.resolvedDisplayName)
        let values = fields.map { store.displayText(for: $0) }
        let layout = MetricsLayout.make(labels: labels, values: values, height: height)
        return makeImage(size: layout.size, scale: scale) { _ in
            layout.draw()
        }
    }

    private static func measureSingleLine(_ text: String, height: CGFloat) -> NSSize {
        let font = NSFont.systemFont(ofSize: 12, weight: .medium)
        let width = ceil(CTMetrics.make(text, font: font).width) + 8
        return NSSize(width: max(width, 24), height: height)
    }

    private static func drawSingleLine(_ text: String, in size: NSSize) {
        let font = NSFont.systemFont(ofSize: 12, weight: .medium)
        let metrics = CTMetrics.make(text, font: font)
        let baseline = ((size.height - metrics.height) / 2) + metrics.descent
        CTMetrics.draw(text, font: font, at: CGPoint(x: 4, y: baseline), canvasHeight: size.height)
    }

    private static func makeImage(size: NSSize, scale: CGFloat, draw: (NSSize) -> Void) -> NSImage {
        let pixelsWide = max(1, Int((size.width * scale).rounded(.up)))
        let pixelsHigh = max(1, Int((size.height * scale).rounded(.up)))
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelsWide,
            pixelsHigh: pixelsHigh,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return NSImage(size: size)
        }
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.shouldAntialias = true
        NSGraphicsContext.current?.imageInterpolation = .high
        draw(size)
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: size)
        image.addRepresentation(rep)
        image.isTemplate = true
        return image
    }
}

private struct CTMetrics {
    var width: CGFloat
    var ascent: CGFloat
    var descent: CGFloat
    var height: CGFloat { ascent + descent }

    static func make(_ text: String, font: NSFont) -> CTMetrics {
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: NSColor.black
        ]))
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
        return CTMetrics(width: width, ascent: ascent, descent: descent)
    }

    static func draw(_ text: String, font: NSFont, at baselineFromBottom: CGPoint, canvasHeight: CGFloat) {
        guard let nsContext = NSGraphicsContext.current else { return }
        let context = nsContext.cgContext
        let attributed = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: NSColor.black
        ])
        let line = CTLineCreateWithAttributedString(attributed)
        context.saveGState()
        let point: CGPoint
        if nsContext.isFlipped {
            context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
            point = CGPoint(x: baselineFromBottom.x, y: canvasHeight - baselineFromBottom.y)
        } else {
            context.textMatrix = .identity
            point = baselineFromBottom
        }
        context.textPosition = point
        CTLineDraw(line, context)
        context.restoreGState()
    }
}

private struct MetricsLayout {
    var size: NSSize
    var labels: [String]
    var values: [String]
    var labelFont: NSFont
    var valueFont: NSFont
    var columnWidths: [CGFloat]
    var columnGap: CGFloat
    var sidePad: CGFloat
    var labelBaseline: CGFloat
    var valueBaseline: CGFloat

    static func make(labels: [String], values: [String], height: CGFloat) -> MetricsLayout {
        var labelSize: CGFloat = 8
        var valueSize: CGFloat = 10.5
        var layout = build(labels: labels, values: values, height: height, labelSize: labelSize, valueSize: valueSize)
        while layout.overflows(height: height), valueSize > 8 {
            valueSize -= 0.5
            labelSize -= 0.25
            layout = build(labels: labels, values: values, height: height, labelSize: labelSize, valueSize: valueSize)
        }
        return layout
    }

    private static func build(labels: [String], values: [String], height: CGFloat, labelSize: CGFloat, valueSize: CGFloat) -> MetricsLayout {
        let labelFont = NSFont.systemFont(ofSize: labelSize, weight: .semibold)
        let valueFont = NSFont.monospacedDigitSystemFont(ofSize: valueSize, weight: .bold)
        let columnGap: CGFloat = 7
        let sidePad: CGFloat = 3
        let gap: CGFloat = 1
        var widths: [CGFloat] = []
        var total = sidePad * 2
        var maxLabel = CTMetrics.make("W", font: labelFont)
        var maxValue = CTMetrics.make("0", font: valueFont)
        for index in labels.indices {
            let label = CTMetrics.make(labels[index], font: labelFont)
            let value = CTMetrics.make(values[index], font: valueFont)
            maxLabel = label.height > maxLabel.height ? label : maxLabel
            maxValue = value.height > maxValue.height ? value : maxValue
            let width = ceil(max(label.width, value.width))
            widths.append(width)
            if index > 0 { total += columnGap }
            total += width
        }
        let block = maxLabel.height + gap + maxValue.height
        let bottomPad = max(1, (height - block) / 2)
        let valueBaseline = bottomPad + maxValue.descent
        let labelBaseline = valueBaseline + maxValue.ascent + gap + maxLabel.descent
        return MetricsLayout(
            size: NSSize(width: total, height: height),
            labels: labels,
            values: values,
            labelFont: labelFont,
            valueFont: valueFont,
            columnWidths: widths,
            columnGap: columnGap,
            sidePad: sidePad,
            labelBaseline: labelBaseline,
            valueBaseline: valueBaseline
        )
    }

    func overflows(height: CGFloat) -> Bool {
        let top = labelBaseline + CTMetrics.make(labels.first ?? "W", font: labelFont).ascent
        return top > height - 0.5
    }

    func draw() {
        var x = sidePad
        for index in labels.indices {
            CTMetrics.draw(labels[index], font: labelFont, at: CGPoint(x: x, y: labelBaseline), canvasHeight: size.height)
            CTMetrics.draw(values[index], font: valueFont, at: CGPoint(x: x, y: valueBaseline), canvasHeight: size.height)
            x += columnWidths[index] + columnGap
        }
    }
}
