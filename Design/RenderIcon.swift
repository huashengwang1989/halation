#!/usr/bin/env swift
//
// Renders the Halation app icon.
//
// This file is the artwork. There is no .psd or .sketch to go looking for, and
// no dependency beyond the toolchain the app already needs — run it and the
// PNGs come back identical, which is the property a checked-in binary asset
// does not have.
//
//   swift Design/RenderIcon.swift
//
// It writes Design/out/:
//   layer-bloom.png, layer-core.png   the two layers Icon Composer stacks
//   icon-1024.png                     the flattened tile, for the .icns fallback
//
// The subject is the thing the app is named after. Halation is the warm bloom
// that spreads around a bright highlight on film: light passes through the
// emulsion, reflects off the base behind it, and re-exposes the grain from the
// wrong side. So the icon is a hot core inside a red-orange bloom — which is
// also, conveniently, what a diffusion model does when it resolves an image out
// of noise.

import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

let size = 1024.0
let outputDirectory = URL(fileURLWithPath: "Design/out", isDirectory: true)

// MARK: - Palette
//
// Warm bloom against a cold ground: the contrast is what makes the glow read as
// light rather than as paint. Values are linear-ish sRGB, picked to stay legible
// at 16 pt where the bloom collapses to a single warm pixel ring.

func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(srgbRed: r, green: g, blue: b, alpha: a)
}

let groundTop = rgb(0.09, 0.10, 0.16)
let groundBottom = rgb(0.03, 0.03, 0.06)
let bloomInner = rgb(1.00, 0.62, 0.26, 0.95)
let bloomOuter = rgb(0.86, 0.16, 0.11, 0.0)
let coreHot = rgb(1.00, 1.00, 1.00)
let coreEdge = rgb(1.00, 0.88, 0.66)

// MARK: - Canvas

func makeContext() -> CGContext {
    let context = CGContext(
        data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8,
        bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setAllowsAntialiasing(true)
    context.interpolationQuality = .high
    return context
}

func write(_ image: CGImage, to name: String) throws {
    try FileManager.default.createDirectory(at: outputDirectory,
                                            withIntermediateDirectories: true)
    let url = outputDirectory.appendingPathComponent(name)
    let rep = NSBitmapImageRep(cgImage: image)
    rep.size = NSSize(width: size, height: size)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try data.write(to: url)
    print("  \(name)  \(Int(size))×\(Int(size))  \(data.count / 1024) KB")
}

/// Apple's icon tile is a squircle, not a rounded rectangle — the corners have
/// no seam where the arc meets the straight edge. Sampling a superellipse gets
/// close enough that the difference is invisible at any size the icon is shown.
func squircle(in rect: CGRect, exponent: Double = 5) -> CGPath {
    let path = CGMutablePath()
    let a = rect.width / 2, b = rect.height / 2
    let centre = CGPoint(x: rect.midX, y: rect.midY)
    let steps = 720
    for step in 0...steps {
        let t = Double(step) / Double(steps) * 2 * .pi
        let cosT = cos(t), sinT = sin(t)
        let x = pow(abs(cosT), 2 / exponent) * a * (cosT < 0 ? -1 : 1)
        let y = pow(abs(sinT), 2 / exponent) * b * (sinT < 0 ? -1 : 1)
        let point = CGPoint(x: centre.x + x, y: centre.y + y)
        step == 0 ? path.move(to: point) : path.addLine(to: point)
    }
    path.closeSubpath()
    return path
}

func blur(_ image: CGImage, radius: Double) -> CGImage {
    let filter = CIFilter.gaussianBlur()
    // Clamped first, or the blur pulls transparent edges inward and leaves a
    // dark rim where the glow should be brightest.
    let clamp = CIFilter.affineClamp()
    clamp.inputImage = CIImage(cgImage: image)
    clamp.transform = .identity
    filter.inputImage = clamp.outputImage
    filter.radius = Float(radius)
    let context = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])
    let extent = CGRect(x: 0, y: 0, width: size, height: size)
    return context.createCGImage(filter.outputImage!, from: extent)!
}

// MARK: - Layers

/// The bloom, which is the whole point of the name.
///
/// Halation spreads *from* the bright part, so the glow peaks on the ring and
/// falls away in both directions — inwards to a shadowed centre, outwards to
/// nothing. Built as one radial gradient with a stop sitting on the ring rather
/// than as concentric strokes: a stroke has an outer edge, and at 1024 pt that
/// edge is plainly visible as a hard circle no amount of blur removes.
///
/// The layer is drawn **opaque**, ground and all, and that is the whole trick.
/// The layered renderer on macOS 26 lights a group from its layers' alpha
/// silhouette, and a soft glow crosses any alpha threshold at exactly one
/// radius — so a translucent bloom comes back with a thin circle etched round
/// it, and the layer beneath tinted through it. Filling edge to edge leaves no
/// silhouette to find. It costs nothing: this layer is the backmost one, so
/// there is nothing behind it to show through anyway.
func renderBloom(ringRadius: Double) -> CGImage {
    let context = makeContext()
    let centre = CGPoint(x: size / 2, y: size / 2)

    let ground = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                            colors: [groundTop, groundBottom] as CFArray,
                            locations: [0, 1])!
    context.drawLinearGradient(ground, start: CGPoint(x: 0, y: size),
                               end: CGPoint(x: 0, y: 0), options: [])
    let reach = size * 0.60
    let peak = ringRadius / reach

    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
        colors: [rgb(0.38, 0.11, 0.05, 0.42),   // shadowed centre
                 rgb(0.95, 0.35, 0.12, 0.78),   // warming towards the ring
                 rgb(1.00, 0.58, 0.22, 0.95),   // on the ring: the bloom itself
                 rgb(0.85, 0.22, 0.10, 0.34),   // spilling outwards
                 rgb(0.70, 0.12, 0.06, 0.0)] as CFArray,
        locations: [0, peak * 0.55, peak, peak + (1 - peak) * 0.22, 1])!
    context.drawRadialGradient(gradient, startCenter: centre, startRadius: 0,
                               endCenter: centre, endRadius: reach,
                               options: .drawsBeforeStartLocation)

    return blur(context.makeImage()!, radius: size * 0.022)
}

/// The core: the highlight the bloom is coming from. A ring rather than a disc,
/// so there is something to recognise — an aperture, a lens, a frame of film
/// seen end-on — instead of a featureless dot.
///
/// This layer is the one that has to survive 16 pt, where the bloom collapses to
/// a warm smudge and only the ring is still legible.
func renderCore(radius: Double) -> CGImage {
    let context = makeContext()
    let centre = CGPoint(x: size / 2, y: size / 2)
    let width = size * 0.060

    context.setLineWidth(width)
    context.setLineCap(.round)
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                              colors: [coreHot, coreEdge] as CFArray,
                              locations: [0, 1])!

    // The ring is drawn as a clip, then filled with a gradient, so the top of
    // the stroke is hotter than the bottom and it reads as lit rather than flat.
    context.saveGState()
    context.addArc(center: centre, radius: radius, startAngle: 0,
                   endAngle: 2 * .pi, clockwise: false)
    context.replacePathWithStrokedPath()
    context.clip()
    context.drawLinearGradient(gradient,
                               start: CGPoint(x: 0, y: size * 0.78),
                               end: CGPoint(x: 0, y: size * 0.22),
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    context.restoreGState()

    // No hand-painted highlight. One used to sit at the upper left, and it has
    // to go: it is a soft radial spot, so the layered renderer traces its alpha
    // edge as a small circle. macOS 26 lights the layer itself, and for the flat
    // tile the ring's own top-to-bottom gradient already reads as lit.
    return context.makeImage()!
}

/// The flattened tile for the `.icns`, where the system supplies no background
/// and no shape. Icon Composer does both itself, which is why its layers are
/// full-bleed and this one is not.
func renderTile(bloom: CGImage, core: CGImage) -> CGImage {
    let context = makeContext()
    // macOS draws app icons inset from the canvas, with the tile at about 80%.
    let inset = size * 0.098
    let tile = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let shape = squircle(in: tile)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -size * 0.012),
                      blur: size * 0.03, color: rgb(0, 0, 0, 0.45))
    context.addPath(shape)
    context.setFillColor(groundBottom)
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(shape)
    context.clip()
    context.draw(bloom, in: CGRect(x: 0, y: 0, width: size, height: size))
    context.draw(core, in: CGRect(x: 0, y: 0, width: size, height: size))
    context.restoreGState()

    return context.makeImage()!
}

// MARK: - Run

let ringRadius = size * 0.205
let bloom = renderBloom(ringRadius: ringRadius)
let core = renderCore(radius: ringRadius)
print("Rendering Halation icon:")
try write(bloom, to: "layer-bloom.png")
try write(core, to: "layer-core.png")
try write(renderTile(bloom: bloom, core: core), to: "icon-1024.png")
print("Done.")
