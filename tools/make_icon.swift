import AppKit
import ImageIO

// Renders the WhoopBuzz app icon: a gradient background with a white "wearable +
// radio waves" SF Symbol. 1024×1024, opaque, no alpha channel (iOS requirement).
// Pure CoreGraphics for reliable offscreen rendering from a CLI.
// Run: swift tools/make_icon.swift <output.png>

let size = 1024
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"

let cs = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
    space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
)!

// Opaque diagonal gradient (deep indigo → vivid teal).
let gradient = CGGradient(colorsSpace: cs, colors: [
    CGColor(red: 0.30, green: 0.16, blue: 0.62, alpha: 1),
    CGColor(red: 0.02, green: 0.65, blue: 0.69, alpha: 1),
] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: []
)

// White SF Symbol via palette colour, drawn as a CGImage centred on the canvas.
let cfg = NSImage.SymbolConfiguration(pointSize: 330, weight: .regular)
    .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
guard let symbol = NSImage(systemSymbolName: "applewatch.radiowaves.left.and.right",
                           accessibilityDescription: nil)?.withSymbolConfiguration(cfg) else {
    fatalError("symbol unavailable")
}
var proposed = NSRect(origin: .zero, size: symbol.size)
let glyph = symbol.cgImage(forProposedRect: &proposed, context: nil, hints: nil)!
let gw = CGFloat(glyph.width), gh = CGFloat(glyph.height)
ctx.draw(glyph, in: CGRect(x: (CGFloat(size) - gw) / 2, y: (CGFloat(size) - gh) / 2, width: gw, height: gh))

let image = ctx.makeImage()!
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: outPath) as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("wrote \(outPath)")
