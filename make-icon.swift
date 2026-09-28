// Regenerates the app icon: swift make-icon.swift Ruler/Assets.xcassets/AppIcon.appiconset/icon.png
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let n = 1024
let cs = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: n, height: n, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func rgb(_ h: Int) -> CGColor {
    CGColor(red: CGFloat((h >> 16) & 255) / 255, green: CGFloat((h >> 8) & 255) / 255, blue: CGFloat(h & 255) / 255, alpha: 1)
}

// Background: blue vertical gradient.
let bg = CGGradient(colorsSpace: cs, colors: [rgb(0x3B82F6), rgb(0x1E3A8A)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: CGFloat(n)), end: .zero, options: [])

// Ruler: diagonal, centered.
let len: CGFloat = 1000, wid: CGFloat = 300
ctx.translateBy(x: CGFloat(n) / 2, y: CGFloat(n) / 2)
ctx.rotate(by: .pi / 4)
let body = CGRect(x: -len / 2, y: -wid / 2, width: len, height: wid)
ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 40, color: CGColor(gray: 0, alpha: 0.45))
ctx.addPath(CGPath(roundedRect: body, cornerWidth: 28, cornerHeight: 28, transform: nil))
ctx.setFillColor(rgb(0xFACC15))
ctx.fillPath()
ctx.setShadow(offset: .zero, blur: 0, color: nil)

// Ticks along the top edge.
ctx.setFillColor(rgb(0x1F2937))
let step: CGFloat = 36, tw: CGFloat = 10
var i = 0
var x = -len / 2 + 60
while x < len / 2 - 50 {
    let h: CGFloat = i % 10 == 0 ? 150 : i % 5 == 0 ? 110 : 65
    ctx.fill(CGRect(x: x - tw / 2, y: wid / 2 - h, width: tw, height: h))
    x += step; i += 1
}

let img = ctx.makeImage()!
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, img, nil)
CGImageDestinationFinalize(dest)
