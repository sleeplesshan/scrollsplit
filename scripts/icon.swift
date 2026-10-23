import AppKit

let destination = CommandLine.arguments[1] + "/AppIcon.iconset"
try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let p = CGFloat(pixels)
        let inset = p * 0.06
        NSColor(red: 0.12, green: 0.43, blue: 0.39, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: inset, y: inset, width: p - inset * 2, height: p - inset * 2), xRadius: p * 0.22, yRadius: p * 0.22).fill()
        NSColor(white: 0.98, alpha: 1).setStroke()
        for (x, up) in [(0.36, true), (0.64, false)] {
            let path = NSBezierPath()
            path.lineWidth = p * 0.065
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            let end = up ? 0.72 : 0.28
            let tail = up ? 0.28 : 0.72
            let wing = up ? 0.60 : 0.40
            path.move(to: NSPoint(x: p * x, y: p * tail))
            path.line(to: NSPoint(x: p * x, y: p * end))
            path.move(to: NSPoint(x: p * (x - 0.10), y: p * wing))
            path.line(to: NSPoint(x: p * x, y: p * end))
            path.line(to: NSPoint(x: p * (x + 0.10), y: p * wing))
            path.stroke()
        }
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(destination)/icon_\(size)x\(size)\(suffix).png"))
    }
}
