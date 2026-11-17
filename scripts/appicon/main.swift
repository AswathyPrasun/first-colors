// Renders the placeholder app icon from the bundled apple drawing.
// Build and run with scripts/make_app_icon.sh (macOS).
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let svg = try Data(contentsOf: root.appendingPathComponent("Resources/Drawings/apple.svg"))
let item = ContentItem(id: "apple", category: .fruits, name: LocalizedText(en: "Apple"), regions: [
    RegionSpec(id: "body", suggested: ["#E53935"]),
    RegionSpec(id: "stem", suggested: ["#6D4C41"]),
    RegionSpec(id: "leaf", suggested: ["#43A047"]),
])
let drawing = DrawingBuilder.build(item: item, document: try SVGDocumentParser.parse(svg))

let side = 1024
let ctx = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func color(_ hex: UInt32) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}
// Warm yellow background (the app's primary button color), no transparency (App Store rule).
ctx.setFillColor(color(0xFFC233))
ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
// A soft lighter circle behind the apple.
ctx.setFillColor(color(0xFFE08A))
ctx.fillEllipse(in: CGRect(x: 112, y: 112, width: 800, height: 800))

ctx.translateBy(x: 0, y: CGFloat(side))
ctx.scaleBy(x: 1, y: -1)
// Fit the 300-unit drawing into the middle 78% of the icon.
let scale = CGFloat(side) * 0.78 / 300
ctx.translateBy(x: (CGFloat(side) - 300 * scale) / 2, y: (CGFloat(side) - 300 * scale) / 2 + 10)
ctx.scaleBy(x: scale, y: scale)
let fills: [String: UInt32] = ["body": 0xE53935, "stem": 0x6D4C41, "leaf": 0x43A047]
for region in drawing.regions {
    ctx.setFillColor(color(fills[region.id] ?? 0xFFFFFF))
    ctx.addPath(region.visiblePath.cgPath)
    ctx.fillPath()
}
let ink = color(0x1F1F1F)
ctx.setFillColor(ink)
ctx.setStrokeColor(ink)
for region in drawing.regions {
    ctx.addPath(region.outline.cgPath)
    ctx.fillPath()
}
ctx.setLineWidth(DrawingStyle.detailLineWidth)
ctx.setLineCap(.round)
for detail in drawing.details {
    ctx.addPath(detail.path.cgPath)
    if detail.style == .fill { ctx.fillPath() } else { ctx.strokePath() }
}

let out = root.appendingPathComponent("Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
precondition(CGImageDestinationFinalize(dest))
print("wrote", out.path)
