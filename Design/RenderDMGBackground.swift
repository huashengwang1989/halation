#!/usr/bin/env swift
//
// Renders the disk image's window background.
//
//   swift Design/RenderDMGBackground.swift
//
// Writes Design/out/dmg-bg.png and dmg-bg@2x.png. Scripts/make_dmg.sh combines
// them into a single multi-resolution TIFF, which is the only way a DMG
// background stays sharp on a Retina display — Finder picks the representation,
// and given a lone 1x PNG it upscales it.
//
// The canvas matches the Finder window's *content* size exactly. Any mismatch
// and Finder tiles or crops the image rather than fitting it, so the numbers
// here and the window bounds in make_dmg.sh have to move together.
//
// The background is light on purpose, and it is the one real compromise in this
// file. Finder draws icon labels in the system's text colour, which is dark in
// light mode and white in dark mode, and a background cannot respond to either.
// Light loses a little contrast under the labels in dark mode; dark loses all of
// it in light mode, which is the more common setting and the worse failure.

import AppKit
import Foundation

let width = 640.0, height = 400.0
let outputDirectory = URL(fileURLWithPath: "Design/out", isDirectory: true)

func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(srgbRed: r, green: g, blue: b, alpha: a)
}

/// A warm off-white rather than pure white, so the window reads as a surface
/// instead of a hole, and picks up the icon's amber without competing with it.
let paperTop = rgb(0.98, 0.97, 0.96)
let paperBottom = rgb(0.93, 0.91, 0.89)
let arrowColour = rgb(0.62, 0.58, 0.55, 0.85)

func render(scale: Double) -> CGImage {
    let w = Int(width * scale), h = Int(height * scale)
    let context = CGContext(
        data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setAllowsAntialiasing(true)
    context.scaleBy(x: scale, y: scale)

    let paper = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                           colors: [paperTop, paperBottom] as CFArray,
                           locations: [0, 1])!
    context.drawLinearGradient(paper, start: CGPoint(x: 0, y: height),
                               end: CGPoint(x: 0, y: 0), options: [])

    // The arrow sits at the vertical centre of the two icons, not of the window:
    // each icon carries a label beneath it, so the pair's visual centre is above
    // the geometric one. 190 from the top is where make_dmg.sh places them.
    drawArrow(in: context, centre: CGPoint(x: width / 2, y: height - 190))
    return context.makeImage()!
}

/// A shaft-and-head arrow, drawn as one filled path so the join between them is
/// seamless at any size. Muted rather than black: it is a hint about what to do,
/// not a control, and it should lose to the two icons it sits between.
func drawArrow(in context: CGContext, centre: CGPoint) {
    let length = 86.0        // overall, tip to tail
    let shaft = 13.0         // shaft thickness
    let headLength = 34.0
    let headSpan = 27.0      // half-height of the head

    context.saveGState()
    context.translateBy(x: centre.x, y: centre.y)
    context.setFillColor(arrowColour)

    let tip = length / 2
    let tail = -length / 2
    let neck = tip - headLength

    let path = CGMutablePath()
    path.move(to: CGPoint(x: tail, y: shaft / 2))
    path.addLine(to: CGPoint(x: neck, y: shaft / 2))
    path.addLine(to: CGPoint(x: neck, y: headSpan))
    path.addLine(to: CGPoint(x: tip, y: 0))
    path.addLine(to: CGPoint(x: neck, y: -headSpan))
    path.addLine(to: CGPoint(x: neck, y: -shaft / 2))
    path.addLine(to: CGPoint(x: tail, y: -shaft / 2))
    path.closeSubpath()

    context.addPath(path)
    context.fillPath()
    context.restoreGState()
}

func write(_ image: CGImage, to name: String, scale: Double) throws {
    try FileManager.default.createDirectory(at: outputDirectory,
                                            withIntermediateDirectories: true)
    let rep = NSBitmapImageRep(cgImage: image)
    // The rep must advertise the *point* size, not the pixel size, or tiffutil
    // treats the 2x image as a second, larger picture instead of the same one at
    // a higher density.
    rep.size = NSSize(width: width, height: height)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try data.write(to: outputDirectory.appendingPathComponent(name))
    print("  \(name)  \(Int(width * scale))×\(Int(height * scale))  \(data.count / 1024) KB")
}

print("Rendering disk image background:")
try write(render(scale: 1), to: "dmg-bg.png", scale: 1)
try write(render(scale: 2), to: "dmg-bg@2x.png", scale: 2)
print("Done.")
