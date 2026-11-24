// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 adri23rep-stack (original BloomBox material only).
// Additional author-attribution term under AGPLv3 section 7(b):
// see LICENSE-ADDITIONAL-TERMS.md.

import AppKit
import CoreGraphics
import Foundation

// BloomBox: a blooming flower rising out of a geometric box.
// Deterministic, original vector artwork. Used to populate standard icon
// asset catalog slots and legacy PNGs before the Xcode build.
let size: CGFloat = 1024
func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: r, green: g, blue: b, alpha: a)
}
func drawIcon(in rect: NSRect) {
    let scale = rect.width / size
    NSGraphicsContext.current?.saveGraphicsState()
    NSGraphicsContext.current!.cgContext.scaleBy(x: scale, y: scale)

    let canvas = NSRect(x: 0, y: 0, width: 1024, height: 1024)
    let bg = NSBezierPath(roundedRect: canvas.insetBy(dx: 8, dy: 8), xRadius: 215, yRadius: 215)
    NSGradient(colors: [
        rgb(0.11, 0.10, 0.31),
        rgb(0.20, 0.11, 0.40),
        rgb(0.08, 0.28, 0.40),
    ])!.draw(in: bg, angle: 130)

    let glow = NSBezierPath(ovalIn: NSRect(x: 190, y: 280, width: 640, height: 640))
    rgb(0.37, 0.90, 0.76, 0.12).setFill()
    glow.fill()

    let cx: CGFloat = 512
    let cy: CGFloat = 650
    let petalColor = rgb(0.48, 0.94, 0.77)
    for i in 0..<6 {
        let angle = CGFloat(i) * (.pi / 3)
        let dx = cos(angle) * 112
        let dy = sin(angle) * 112
        let petal = NSBezierPath(ovalIn: NSRect(x: cx + dx - 66, y: cy + dy - 92, width: 132, height: 184))
        petalColor.withAlphaComponent(0.93).setFill()
        petal.fill()
    }

    let center = NSBezierPath(ovalIn: NSRect(x: cx - 66, y: cy - 66, width: 132, height: 132))
    rgb(0.95, 0.84, 0.53).setFill()
    center.fill()

    // Angular BloomBox container, distinct from Manzana's apple-shaped icon.
    let back = NSBezierPath()
    back.move(to: NSPoint(x: 512, y: 464))
    back.line(to: NSPoint(x: 764, y: 378))
    back.line(to: NSPoint(x: 512, y: 265))
    back.line(to: NSPoint(x: 260, y: 378))
    back.close()
    rgb(0.65, 0.53, 0.99).setFill()
    back.fill()

    let left = NSBezierPath()
    left.move(to: NSPoint(x: 260, y: 378))
    left.line(to: NSPoint(x: 512, y: 265))
    left.line(to: NSPoint(x: 512, y: 125))
    left.line(to: NSPoint(x: 260, y: 244))
    left.close()
    rgb(0.34, 0.69, 0.88).setFill()
    left.fill()

    let right = NSBezierPath()
    right.move(to: NSPoint(x: 512, y: 265))
    right.line(to: NSPoint(x: 764, y: 378))
    right.line(to: NSPoint(x: 764, y: 244))
    right.line(to: NSPoint(x: 512, y: 125))
    right.close()
    rgb(0.27, 0.40, 0.75).setFill()
    right.fill()

    // A thin bright fold line visually ties the box and flower together.
    let fold = NSBezierPath()
    fold.move(to: NSPoint(x: 263, y: 378))
    fold.line(to: NSPoint(x: 512, y: 266))
    fold.line(to: NSPoint(x: 761, y: 378))
    fold.lineWidth = 10
    fold.lineCapStyle = .round
    rgb(0.89, 0.99, 0.95, 0.65).setStroke()
    fold.stroke()

    NSGraphicsContext.current?.restoreGraphicsState()
}

// The layered icon is the single source for the primary mascot.
enum BloomAppearance { case normal, dark, tinted }
func drawBloom(in rect: NSRect, appearance: BloomAppearance) {
    let colors: [NSColor]
    switch appearance {
    case .normal: colors = [rgb(0.78039, 0.48235, 0.96471), rgb(0.32157, 0.04314, 0.91373)]
    case .dark: colors = [rgb(0.15, 0.15, 0.18), rgb(0.06, 0.06, 0.08)]
    case .tinted: colors = [rgb(0.25, 0.25, 0.25), rgb(0.10, 0.10, 0.10)]
    }
    NSGradient(colors: colors)!.draw(in: rect, angle: -45)
    let files = ["01_Oreja_izquierda", "02_Cuerpo_verde", "03_Carita", "04_Oreja_derecha", "05_Ojitos"]
    for (index, name) in files.enumerated() {
        let path = "AppIcon.icon/Assets/\(name).svg"
        guard let image = NSImage(contentsOfFile: path) else { fatalError("Cannot open Bloom layer: \(path)") }
        if appearance == .tinted {
            let mask = NSImage(size: rect.size, flipped: false) { bounds in
                image.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1)
                let gray: CGFloat = index == 4 ? 0.12549 : index == 2 ? 1 : 0.69020
                NSColor(white: gray, alpha: 1).setFill()
                bounds.fill(using: .sourceIn)
                return true
            }
            mask.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        } else {
            image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        }
    }
}

func save(_ file: String, width: Int, height: Int, bloom: BloomAppearance? = nil) throws {
    guard let bmp = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: width * 4, bitsPerPixel: 32
    ) else { fatalError("Cannot allocate icon bitmap") }

    guard let context = NSGraphicsContext(bitmapImageRep: bmp) else {
        fatalError("Cannot construct image context")
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let rect = NSRect(x: 0, y: 0, width: width, height: height)
    if let appearance = bloom { drawBloom(in: rect, appearance: appearance) }
    else { drawIcon(in: rect) }
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard let data = bmp.representation(using: .png, properties: [:]) else {
        fatalError("Cannot encode PNG")
    }
    let dest = URL(fileURLWithPath: file)
    try FileManager.default.createDirectory(
        at: dest.deletingLastPathComponent(), withIntermediateDirectories: true
    )
    try data.write(to: dest)
}

do {
    let catalog = "Resources/Assets.xcassets/AppIcon.appiconset"
    let variants: [(String, BloomAppearance)] = [("AppIcon1024.png", .normal), ("AppIconDark1024.png", .dark), ("AppIconDark1024 1.png", .tinted)]
    for (name, appearance) in variants {
        try save("\(catalog)/\(name)", width: 1024, height: 1024, bloom: appearance)
    }
    // Generate every app icon from our own vector artwork at build time.
    // Do not keep binary copies from legacy source distributions in Git.
    let greyCatalog = "Resources/Assets.xcassets/AppIconGrey.appiconset"
    for name in ["AppIconGrey1024.png", "AppIconGreyDark1024.png", "AppIconGreyDark1024 1.png"] {
        try save("\(greyCatalog)/\(name)", width: 1024, height: 1024)
    }
    try save("Resources/Branding/AppIcon60x60@2x.png", width: 120, height: 120, bloom: .normal)
    try save("Resources/Branding/AppIcon76x76@2x~ipad.png", width: 152, height: 152, bloom: .normal)
    try save("Resources/Branding/BloomBox1024.png", width: 1024, height: 1024, bloom: .normal)
    print("Generated Bloom mascot fallback and preserved alternate icon (1024px, 120px, 152px).")
} catch {
    fputs("BloomBox icon generation failed: \(error)\n", stderr)
    exit(1)
}

// Fail fast on the same native asset compiler used for archive. Do not silently
// substitute flattened artwork when a layered icon is malformed.
if ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] == "true" {
    let output = FileManager.default.temporaryDirectory.appendingPathComponent("bloom-icon-preflight-" + UUID().uuidString)
    do {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: output) }
        let tool = Process()
        tool.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        tool.arguments = ["actool", "--compile", output.path,
            "--platform", "iphoneos", "--minimum-deployment-target", "15.0",
            "--target-device", "iphone", "--target-device", "ipad",
            "--app-icon", "AppIcon", "--include-all-app-icons",
            "--output-partial-info-plist", output.appendingPathComponent("Info.plist").path,
            "--output-format", "human-readable-text", "--warnings", "--errors",
            "AppIcon.icon", "Resources/Assets.xcassets"]
        try tool.run()
        tool.waitUntilExit()
        guard tool.terminationStatus == 0,
              FileManager.default.fileExists(atPath: output.appendingPathComponent("Assets.car").path) else {
            fatalError("Native Bloom icon actool preflight failed (status \(tool.terminationStatus))")
        }
        print("Native Bloom icon actool preflight succeeded.")
    } catch {
        fputs("Native Bloom icon validation failed: \(error)\n", stderr)
        exit(1)
    }
}
