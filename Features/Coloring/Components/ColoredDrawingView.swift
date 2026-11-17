import SwiftUI

/// A finished picture (fills + crayon + outlines), not interactive. Used by the celebration.
struct ColoredDrawingView: View {
    let drawing: Drawing
    let fills: [String: String]
    let strokes: [Stroke]

    @State private var rasterizer = StrokeRasterizer()
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let colors = fills.compactMapValues { Color(hexString: $0) }
        let rasterizer = rasterizer
        let scale = displayScale
        Canvas { context, size in
            DrawingRenderer.drawBackgroundAndFills(drawing, fills: colors, in: context, size: size)
            if !strokes.isEmpty,
               let image = rasterizer.image(strokes: strokes, drawing: drawing, size: size, scale: scale) {
                context.draw(Image(decorative: image, scale: 1), in: CGRect(origin: .zero, size: size))
            }
            DrawingRenderer.drawOutlinesAndDetails(drawing, in: context, size: size)
        }
        .aspectRatio(drawing.viewBox.width / drawing.viewBox.height, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
