import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Renders drawings to images off the main thread (thumbnails, blank outlines, Photos export).
protocol RenderServicing: Sendable {
    /// PNG of the drawing with the child's fills and strokes.
    func thumbnailPNG(itemId: String, fills: [String: String], strokes: [Stroke]) async -> Data?
    /// The uncolored outline, for picker tiles that have no saved art yet (cached).
    func blankThumbnail(itemId: String) async -> CGImage?
    /// Full-quality PNG for Photos, rendered on demand (never stored, CLAUDE.md §8).
    func exportPNG(itemId: String, fills: [String: String], strokes: [Stroke]) async -> Data?
}

actor RenderService: RenderServicing {
    static let thumbnailSide = 300
    static let exportSide = 2048

    private let content: any ContentProviding
    private var blankCache: [String: CGImage] = [:]

    init(content: any ContentProviding) {
        self.content = content
    }

    func thumbnailPNG(itemId: String, fills: [String: String], strokes: [Stroke]) async -> Data? {
        guard let drawing = content.drawing(for: itemId),
              let image = DrawingImageRenderer.render(drawing, fills: fills, strokes: strokes,
                                                      pixelSide: Self.thumbnailSide)
        else { return nil }
        return DrawingImageRenderer.pngData(image)
    }

    func exportPNG(itemId: String, fills: [String: String], strokes: [Stroke]) async -> Data? {
        guard let drawing = content.drawing(for: itemId),
              let image = DrawingImageRenderer.render(drawing, fills: fills, strokes: strokes, pixelSide: Self.exportSide)
        else { return nil }
        return DrawingImageRenderer.pngData(image)
    }

    func blankThumbnail(itemId: String) async -> CGImage? {
        if let cached = blankCache[itemId] { return cached }
        guard let drawing = content.drawing(for: itemId),
              let image = DrawingImageRenderer.render(drawing, fills: [:], strokes: [], pixelSide: Self.thumbnailSide)
        else { return nil }
        blankCache[itemId] = image
        return image
    }
}

/// Pure Core Graphics version of the canvas layers, safe on any thread.
/// Same order as the screen: white, fills, crayon (clipped), outlines, face.
enum DrawingImageRenderer {
    static func render(_ drawing: Drawing, fills: [String: String], strokes: [Stroke], pixelSide: Int) -> CGImage? {
        let size = CGSize(width: pixelSide, height: pixelSide)
        guard pixelSide > 0, let ctx = CGContext(
            data: nil, width: pixelSide, height: pixelSide, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }

        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(origin: .zero, size: size))

        // Top-left origin like the screen.
        ctx.translateBy(x: 0, y: size.height)
        ctx.scaleBy(x: 1, y: -1)
        let transform = DrawingRenderer.transform(for: drawing.viewBox, in: size)

        ctx.saveGState()
        ctx.concatenate(transform)
        for region in drawing.regions {
            guard let hex = fills[region.id], let color = cgColor(hex) else { continue }
            ctx.addPath(region.visiblePath.cgPath)
            ctx.setFillColor(color)
            ctx.fillPath()
        }
        ctx.restoreGState()

        if !strokes.isEmpty,
           let strokeImage = StrokeRasterizer().image(strokes: strokes, drawing: drawing, size: size, scale: 1) {
            // CGContext draws images bottom-up; undo our flip just for this draw.
            ctx.saveGState()
            ctx.translateBy(x: 0, y: size.height)
            ctx.scaleBy(x: 1, y: -1)
            ctx.draw(strokeImage, in: CGRect(origin: .zero, size: size))
            ctx.restoreGState()
        }

        ctx.saveGState()
        ctx.concatenate(transform)
        let ink = CGColor(red: 0x1F / 255, green: 0x1F / 255, blue: 0x1F / 255, alpha: 1)
        ctx.setFillColor(ink)
        ctx.setStrokeColor(ink)
        for region in drawing.regions {
            ctx.addPath(region.outline.cgPath)
            ctx.fillPath()
        }
        ctx.setLineWidth(DrawingStyle.detailLineWidth)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        for detail in drawing.details {
            ctx.addPath(detail.path.cgPath)
            switch detail.style {
            case .fill: ctx.fillPath()
            case .stroke: ctx.strokePath()
            }
        }
        ctx.restoreGState()
        return ctx.makeImage()
    }

    static func pngData(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    private static func cgColor(_ hex: String) -> CGColor? {
        guard let rgb = HexColor.parse(hex) else { return nil }
        return CGColor(red: CGFloat((rgb >> 16) & 0xFF) / 255, green: CGFloat((rgb >> 8) & 0xFF) / 255,
                       blue: CGFloat(rgb & 0xFF) / 255, alpha: 1)
    }
}
