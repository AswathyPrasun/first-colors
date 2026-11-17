import SwiftUI

/// Draws a `Drawing` into a SwiftUI `GraphicsContext`, scaled to fit.
/// Order (CLAUDE.md §6): white background → region fills → [crayon strokes] → outlines → details.
/// The coloring screen draws the crayon layer between these two calls.
enum DrawingRenderer {
    /// Aspect-fit transform from drawing coordinates to a canvas of `size`, centered.
    static func transform(for viewBox: CGRect, in size: CGSize) -> CGAffineTransform {
        guard viewBox.width > 0, viewBox.height > 0 else { return .identity }
        let scale = min(size.width / viewBox.width, size.height / viewBox.height)
        let dx = (size.width - viewBox.width * scale) / 2 - viewBox.minX * scale
        let dy = (size.height - viewBox.height * scale) / 2 - viewBox.minY * scale
        return CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: dx, ty: dy)
    }

    static func drawBackgroundAndFills(_ drawing: Drawing, fills: [String: Color],
                                       in context: GraphicsContext, size: CGSize) {
        var ctx = context
        ctx.concatenate(transform(for: drawing.viewBox, in: size))
        for region in drawing.regions {
            ctx.fill(region.visiblePath, with: .color(.white))
            if let color = fills[region.id] {
                ctx.fill(region.visiblePath, with: .color(color))
            }
        }
    }

    static func drawOutlinesAndDetails(_ drawing: Drawing, in context: GraphicsContext, size: CGSize) {
        var ctx = context
        ctx.concatenate(transform(for: drawing.viewBox, in: size))
        let ink = GraphicsContext.Shading.color(DSColor.outline)
        for region in drawing.regions {
            ctx.fill(region.outline, with: ink)
        }
        let detailStroke = StrokeStyle(lineWidth: DrawingStyle.detailLineWidth, lineCap: .round, lineJoin: .round)
        for detail in drawing.details {
            switch detail.style {
            case .fill: ctx.fill(detail.path, with: ink)
            case .stroke: ctx.stroke(detail.path, with: ink, style: detailStroke)
            }
        }
    }

    /// Convenience for thumbnails and previews (no crayon strokes).
    static func draw(_ drawing: Drawing, fills: [String: Color], in context: GraphicsContext, size: CGSize) {
        drawBackgroundAndFills(drawing, fills: fills, in: context, size: size)
        drawOutlinesAndDetails(drawing, in: context, size: size)
    }
}

/// Static, non-interactive picture of a drawing (picker tiles, previews).
struct DrawingPicture: View {
    let drawing: Drawing
    var fills: [String: Color] = [:]

    var body: some View {
        Canvas { context, size in
            DrawingRenderer.draw(drawing, fills: fills, in: context, size: size)
        }
        .aspectRatio(drawing.viewBox.width / drawing.viewBox.height, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
