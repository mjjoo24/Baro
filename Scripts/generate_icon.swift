#!/usr/bin/swift

import AppKit
import Foundation

let projectRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let resourcesDir = projectRoot.appendingPathComponent("Sources/Baro/Resources")
let iconsetDir = projectRoot.appendingPathComponent("build/AppIcon.iconset")
let icnsPath = resourcesDir.appendingPathComponent("AppIcon.icns")

try? FileManager.default.createDirectory(at: resourcesDir, withIntermediateDirectories: true)
try? FileManager.default.removeItem(at: iconsetDir)
try FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

func makeMasterImage(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius = size * 0.22
    let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    path.addClip()

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.20, green: 0.62, blue: 0.86, alpha: 1.0),
        NSColor(calibratedRed: 0.12, green: 0.78, blue: 0.62, alpha: 1.0)
    ])
    gradient?.draw(in: rect, angle: -60)

    let symbolConfig = NSImage.SymbolConfiguration(pointSize: size * 0.52, weight: .semibold)
    if let symbol = NSImage(systemSymbolName: "figure.stand", accessibilityDescription: nil)?
        .withSymbolConfiguration(symbolConfig) {
        let tinted = symbol.tinted(with: .white)
        let symbolSize = tinted.size
        let origin = NSPoint(x: (size - symbolSize.width) / 2, y: (size - symbolSize.height) / 2 - size * 0.03)
        tinted.draw(at: origin, from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    image.unlockFocus()
    return image
}

extension NSImage {
    func tinted(with color: NSColor) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        color.set()
        let rect = NSRect(origin: .zero, size: size)
        rect.fill()
        draw(at: .zero, from: .zero, operation: .destinationIn, fraction: 1.0)
        image.unlockFocus()
        return image
    }
}

func pngData(from image: NSImage, size: CGFloat) -> Data? {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size),
        pixelsHigh: Int(size),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

let master = makeMasterImage(size: 1024)

let sizes: [(name: String, size: CGFloat)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024)
]

for entry in sizes {
    guard let data = pngData(from: master, size: entry.size) else { continue }
    let fileURL = iconsetDir.appendingPathComponent("\(entry.name).png")
    try data.write(to: fileURL)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetDir.path, "-o", icnsPath.path]
try process.run()
process.waitUntilExit()

if process.terminationStatus == 0 {
    print("✅ 아이콘 생성 완료: \(icnsPath.path)")
} else {
    print("❌ iconutil 실패 (exit \(process.terminationStatus))")
    exit(1)
}
